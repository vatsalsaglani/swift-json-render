// Owner: jr-3 (wave 2). The Stack layout: a small flexbox (axis, gap, align, justify, wrap).
internal import SwiftUI

/// Cross-axis alignment.
public enum JRStackAlign: String, Sendable, CaseIterable {
    case start, center, end, stretch
}

/// Main-axis distribution of free space.
public enum JRStackJustify: String, Sendable, CaseIterable {
    case start, center, end, between, around
}

/// Lays children along one axis with a fixed gap.
///
/// - Vertical: each child gets the full proposed width (its own width when it is smaller,
///   unless `align` is `stretch`).
/// - Horizontal: children get their ideal widths; when they do not fit, the space is shared
///   fairly (small children keep their width, wide ones wrap their text).
/// - `wrap` (horizontal only): children flow onto new lines.
/// - `justify` distributes free main-axis space only when the proposal is finite.
struct FlexLayout: Layout {
    var axis: Axis
    var spacing: CGFloat
    var align: JRStackAlign
    var justify: JRStackJustify
    var wrap: Bool

    private struct Line {
        var indices: [Int] = []
        var sizes: [CGSize] = []
        var main: CGFloat = 0
        var cross: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = arrange(proposal: proposal, subviews: subviews)
        let used = lines.map(\.main).max() ?? 0
        let main: CGFloat
        if justify != .start, let available = mainLength(proposal), available.isFinite {
            main = max(used, available)
        } else {
            main = used
        }
        var cross = lines.map(\.cross).reduce(0, +) + spacing * CGFloat(max(lines.count - 1, 0))
        if align == .stretch, let available = crossLength(proposal), available.isFinite {
            cross = max(cross, lines.count == 1 ? available : cross)
        }
        return axis == .vertical
            ? CGSize(width: cross, height: main) : CGSize(width: main, height: cross)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let lines = arrange(proposal: ProposedViewSize(bounds.size), subviews: subviews)
        let boundsMain = axis == .vertical ? bounds.height : bounds.width
        let boundsCross = axis == .vertical ? bounds.width : bounds.height
        var crossOffset: CGFloat = 0
        for line in lines {
            let lineCross = lines.count == 1 ? boundsCross : line.cross
            let free = max(boundsMain - line.main, 0)
            let count = CGFloat(line.indices.count)
            var mainOffset: CGFloat
            var extraGap: CGFloat = 0
            switch justify {
            case .start: mainOffset = 0
            case .center: mainOffset = free / 2
            case .end: mainOffset = free
            case .between:
                mainOffset = 0
                extraGap = count > 1 ? free / (count - 1) : 0
            case .around:
                extraGap = count > 0 ? free / count : 0
                mainOffset = extraGap / 2
            }
            for (position, index) in line.indices.enumerated() {
                var size = line.sizes[position]
                if align == .stretch {
                    if axis == .vertical { size.width = lineCross } else { size.height = lineCross }
                }
                let childCross = axis == .vertical ? size.width : size.height
                let crossPosition: CGFloat =
                    switch align {
                    case .start, .stretch: 0
                    case .center: (lineCross - childCross) / 2
                    case .end: lineCross - childCross
                    }
                let point =
                    axis == .vertical
                    ? CGPoint(
                        x: bounds.minX + crossOffset + crossPosition, y: bounds.minY + mainOffset)
                    : CGPoint(
                        x: bounds.minX + mainOffset, y: bounds.minY + crossOffset + crossPosition)
                subviews[index].place(
                    at: point, anchor: .topLeading,
                    proposal: ProposedViewSize(width: size.width, height: size.height))
                mainOffset += (axis == .vertical ? size.height : size.width) + spacing + extraGap
            }
            crossOffset += lineCross + spacing
        }
    }

    // MARK: - Arrangement

    private func mainLength(_ proposal: ProposedViewSize) -> CGFloat? {
        axis == .vertical ? proposal.height : proposal.width
    }

    private func crossLength(_ proposal: ProposedViewSize) -> CGFloat? {
        axis == .vertical ? proposal.width : proposal.height
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Line] {
        guard !subviews.isEmpty else { return [] }
        return axis == .vertical
            ? [verticalLine(proposal: proposal, subviews: subviews)]
            : horizontalLines(proposal: proposal, subviews: subviews)
    }

    private func verticalLine(proposal: ProposedViewSize, subviews: Subviews) -> Line {
        var line = Line()
        let width = proposal.width
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            guard size != .zero else { continue }
            line.indices.append(index)
            line.sizes.append(size)
            line.cross = max(line.cross, size.width)
        }
        line.main =
            line.sizes.map(\.height).reduce(0, +)
            + spacing * CGFloat(max(line.indices.count - 1, 0))
        return line
    }

    private func horizontalLines(proposal: ProposedViewSize, subviews: Subviews) -> [Line] {
        let available = proposal.width ?? .infinity
        let ideals = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: nil, height: proposal.height))
        }
        // A zero-size child (for example a sheet host) takes no slot and no gap.
        let shown = subviews.indices.filter { ideals[$0] != .zero }
        if wrap {
            var lines: [Line] = []
            var current = Line()
            for index in shown {
                var size = ideals[index]
                if size.width > available {
                    size = subviews[index].sizeThatFits(
                        ProposedViewSize(width: available, height: nil))
                }
                let needed =
                    current.indices.isEmpty ? size.width : current.main + spacing + size.width
                if !current.indices.isEmpty, needed > available {
                    lines.append(current)
                    current = Line()
                }
                current.main =
                    current.indices.isEmpty ? size.width : current.main + spacing + size.width
                current.indices.append(index)
                current.sizes.append(size)
                current.cross = max(current.cross, size.height)
            }
            lines.append(current)
            return lines
        }
        let gaps = spacing * CGFloat(max(shown.count - 1, 0))
        let total = shown.map { ideals[$0].width }.reduce(0, +) + gaps
        var widths = ideals.map(\.width)
        if total > available, available.isFinite {
            var remaining = max(available - gaps, 0)
            var left = shown.count
            for index in shown.sorted(by: { ideals[$0].width < ideals[$1].width }) {
                let share = remaining / CGFloat(left)
                widths[index] = min(ideals[index].width, share)
                remaining -= widths[index]
                left -= 1
            }
        }
        var line = Line()
        for index in shown {
            let size =
                widths[index] == ideals[index].width
                ? ideals[index]
                : subviews[index].sizeThatFits(ProposedViewSize(width: widths[index], height: nil))
            line.indices.append(index)
            line.sizes.append(CGSize(width: widths[index], height: size.height))
            line.cross = max(line.cross, size.height)
        }
        line.main = shown.map { widths[$0] }.reduce(0, +) + gaps
        return [line]
    }
}
