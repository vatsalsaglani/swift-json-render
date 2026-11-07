public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// Parts of a whole with many parts: squarified cells (`TreemapLayout`) drawn on a
/// `Canvas`, a 2 pt gap in the card colour, coloured by group with the categorical palette
/// (one hue without a group). Labels appear only where they fit; every cell is a VoiceOver
/// element and shows a tooltip on hover. More than 200 cells fold into "Other"; one cell
/// shows as a single value.
public struct Treemap: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.treemap.rawValue,
        description:
            "Parts of a whole with many parts: bundle size by module, lines by directory. Values must be greater than zero. group nests one level and colours the cells.",
        props: .object(
            [
                ChartProps.data,
                ChartProps.field("label", "Field for the cell label. Default \"label\"."),
                ChartProps.field(
                    "value", "Field for the cell size (> 0). Default \"value\"."),
                ChartProps.field(
                    "group", "Field that groups and colours the cells.", optional: true),
                PropSchema.Field(
                    name: "maxDepth", schema: PropSchema.number.optional(),
                    description: "2 (default) nests cells in their group; 1 draws a flat map."),
                PropSchema.Field(
                    name: "minLabelArea", schema: PropSchema.number.optional(),
                    description: "Cells smaller than this (pt²) get no label. Default 900."),
            ] + ChartProps.chrome(domains: false)),
        slots: ChartProps.slots,
        example: [
            "data": .array([
                .object(["module": "RafuApp", "lines": 41, "area": "App"]),
                .object(["module": "RafuCore", "lines": 16, "area": "Core"]),
                .object(["module": "Editor", "lines": 8, "area": "Features"]),
            ]),
            "label": "module", "value": "lines", "group": "area",
        ])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .treemap, context: context, make: TreemapData.make) { input in
            TreemapPlot(input: input)
        }
    }
}

/// Treemap data: one point per cell, largest first, with the group as the series. Values
/// that are zero, negative or not numbers are skipped (the validator rejects them).
public enum TreemapData {
    public static let defaultMinLabelArea = 900.0
    static let otherGroup = "Other"

    public static func make(props: [String: JSONValue?]) -> (ChartData, [ChartWarning]) {
        let reader = ChartPropReader(props)
        var warnings: [ChartWarning] = []
        var data = CompositeData.start(kind: .treemap, reader: reader, warnings: &warnings)
        let labelField = reader.string("label") ?? "label"
        let valueField = reader.string("value") ?? "value"
        let groupField = reader.string("group")
        data.xField = labelField
        data.yField = valueField
        var skipped = 0
        var cells: [(label: String, value: Double, group: String)] = []
        for fields in CompositeData.objects(reader, skipped: &skipped) {
            guard let label = ChartValues.text(fields[labelField]),
                let value = ChartValues.number(fields[valueField]), value > 0
            else {
                skipped += 1
                continue
            }
            let group = groupField.flatMap { ChartValues.text(fields[$0]) } ?? ""
            cells.append((label, value, group))
        }
        if skipped > 0 { warnings.append(.skippedRows(skipped)) }
        // Largest first; equal values keep their order.
        cells = cells.enumerated().sorted { lhs, rhs in
            lhs.element.value != rhs.element.value
                ? lhs.element.value > rhs.element.value : lhs.offset < rhs.offset
        }.map(\.element)
        var otherIndex: Int?
        let limit = CompositeBudgets.maxTreemapCells
        if cells.count > limit {
            let rest = cells[(limit - 1)...]
            let sum = rest.reduce(0) { $0 + $1.value }
            let group = groupField == nil ? "" : otherGroup
            cells = Array(cells.prefix(limit - 1)) + [("Other (\(rest.count))", sum, group)]
            otherIndex = limit - 1
            warnings.append(.foldedIntoOther(rest.count))
        }
        let labels = CompositeData.unique(cells.map(\.label))
        data.points = cells.enumerated().map { index, cell in
            ChartPoint(
                id: index, x: .category(labels[index]), xLabel: labels[index], y: cell.value,
                series: cell.group, isOther: index == otherIndex)
        }
        data.categories = labels
        var groups: [String] = []
        var seen = Set<String>()
        for cell in cells where seen.insert(cell.group).inserted { groups.append(cell.group) }
        data.series = groups == [""] ? [] : groups
        CompositeData.finish(
            &data, range: CompositeData.extent(cells.map(\.value) + [0]), reader: reader,
            includeZero: true)
        return (data, warnings)
    }

    /// One drawn cell: the point and its rectangle (after the gap).
    public struct Tile: Sendable, Hashable {
        public var point: ChartPoint
        public var rect: CGRect
    }

    /// The tiles of `data` in `rect`. With series and `maxDepth` 2 the cells nest in their
    /// group (groups in series order); otherwise one flat squarified layout.
    public static func tiles(for data: ChartData, in rect: CGRect, maxDepth: Int, gap: CGFloat)
        -> [Tile]
    {
        let points = data.points
        guard data.hasSeries, maxDepth >= 2 else {
            let cells = TreemapLayout.squarify(values: points.map(\.y), in: rect, gap: gap)
            return zip(points, cells).map { Tile(point: $0, rect: $1.rect) }
        }
        let members = data.series.map { name in points.filter { $0.series == name } }
        let layout = TreemapLayout.squarify(
            groups: members.map { $0.map(\.y) }, in: rect, gap: gap)
        var tiles: [Tile] = []
        for (group, cells) in zip(members, layout.values) {
            tiles += zip(group, cells).map { Tile(point: $0, rect: $1.rect) }
        }
        return tiles
    }
}

/// The default treemap plot: a `Canvas`, a group legend, per-cell accessibility, hover
/// tooltip and click selection.
struct TreemapPlot: View {
    let input: ChartPlotInput

    @State private var hovered: String?
    @Environment(\.self) private var environment

    private static let gap: CGFloat = 2

    var body: some View {
        if input.data.points.count == 1, let only = input.data.points.first {
            SingleValueView(input: input, point: only)
                .frame(maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { proxy in
                    let tiles = TreemapData.tiles(
                        for: input.data, in: CGRect(origin: .zero, size: proxy.size),
                        maxDepth: maxDepth, gap: Self.gap)
                    map(tiles)
                }
                if input.data.hasSeries, input.legend != .hidden {
                    CompositeLegend(
                        entries: input.data.series.enumerated().map { index, name in
                            .init(label: name, color: groupColor(index: index, name: name))
                        }, input: input)
                }
            }
        }
    }

    private var reader: ChartPropReader { ChartPropReader(input.props) }
    private var maxDepth: Int { Int(reader.number("maxDepth") ?? 2) }
    private var minLabelArea: Double {
        reader.number("minLabelArea") ?? TreemapData.defaultMinLabelArea
    }

    private func map(_ tiles: [TreemapData.Tile]) -> some View {
        let total = input.data.points.reduce(0) { $0 + $1.y }
        let focus = input.selection.wrappedValue
        return Canvas { context, _ in
            for tile in tiles where tile.rect.width > 0 && tile.rect.height > 0 {
                let fill = color(for: tile.point)
                let dimmed = input.isDimmed(tile.point.xLabel)
                context.fill(
                    Path(roundedRect: tile.rect, cornerRadius: min(3, tile.rect.width / 4)),
                    with: .color(fill.opacity(dimmed ? 0.35 : 1)))
                if tile.point.xLabel == focus {
                    context.stroke(
                        Path(
                            roundedRect: tile.rect.insetBy(dx: 0.75, dy: 0.75),
                            cornerRadius: min(3, tile.rect.width / 4)),
                        with: .color(input.theme.color.text), lineWidth: 1.5)
                }
                drawLabel(tile, fill: fill, in: &context)
            }
        }
        .accessibilityChildren {
            ZStack(alignment: .topLeading) {
                ForEach(tiles, id: \.point.id) { tile in
                    Rectangle()
                        .fill(.clear)
                        .frame(width: tile.rect.width, height: tile.rect.height)
                        .offset(x: tile.rect.minX, y: tile.rect.minY)
                        .accessibilityLabel(label(tile.point, total: total))
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if let hovered, let tile = tiles.first(where: { $0.point.xLabel == hovered }) {
                ChartTooltip(input, label: hovered)
                    .fixedSize()
                    .offset(x: tile.rect.minX + 4, y: tile.rect.minY + 4)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                hovered = tiles.first(where: { $0.rect.contains(location) })?.point.xLabel
                input.selection.wrappedValue = hovered
            case .ended:
                hovered = nil
                input.selection.wrappedValue = nil
            }
        }
        .onTapGesture { location in
            // A click commits (a second click deselects); hover only highlights.
            input.commit(tiles.first(where: { $0.rect.contains(location) })?.point.xLabel)
        }
    }

    /// The label and value at the top left of a cell, only when the cell is at least
    /// `minLabelArea` and the text fits.
    private func drawLabel(
        _ tile: TreemapData.Tile, fill: Color, in context: inout GraphicsContext
    ) {
        let rect = tile.rect
        guard Double(rect.width * rect.height) >= minLabelArea else { return }
        // The grey "Other" fill is translucent: its label takes the text colour (as in the
        // VPLAN mock); solid palette fills take white or near-black by contrast.
        let ink = isGrey(tile.point) ? input.theme.color.text : textColor(on: fill)
        let room = CGSize(width: rect.width - 10, height: rect.height - 8)
        guard room.width > 0, room.height > 0 else { return }
        let title = context.resolve(
            Text(tile.point.xLabel).font(input.tokens.axisFont.weight(.semibold))
                .foregroundStyle(ink))
        let value = context.resolve(
            Text(input.data.format.axisString(tile.point.y))
                .font(input.tokens.axisFont.monospacedDigit())
                .foregroundStyle(ink.opacity(0.85)))
        let titleSize = title.measure(in: CGSize(width: CGFloat.infinity, height: room.height))
        guard titleSize.width <= room.width, titleSize.height <= room.height else { return }
        let origin = CGPoint(x: rect.minX + 6, y: rect.minY + 4)
        context.draw(title, at: origin, anchor: .topLeading)
        let valueSize = value.measure(in: CGSize(width: CGFloat.infinity, height: room.height))
        if valueSize.width <= room.width, titleSize.height + valueSize.height <= room.height {
            context.draw(
                value, at: CGPoint(x: origin.x, y: origin.y + titleSize.height),
                anchor: .topLeading)
        }
    }

    private func color(for point: ChartPoint) -> Color {
        if point.isOther { return input.colors.other }
        guard input.data.hasSeries, let index = input.data.series.firstIndex(of: point.series)
        else { return input.colors.single }
        return groupColor(index: index, name: point.series)
    }

    /// `true` for the grey cells: the folded "Other" and a group named "Other".
    private func isGrey(_ point: ChartPoint) -> Bool {
        point.isOther || (input.data.hasSeries && point.series == TreemapData.otherGroup)
    }

    /// The group colour; a group named "Other" is grey, like every "Other".
    private func groupColor(index: Int, name: String) -> Color {
        name == TreemapData.otherGroup ? input.colors.other : input.colors.series(index)
    }

    /// White or near-black, whichever has more contrast on `fill` (WCAG luminance). The
    /// theme's text colours flip with the scheme, so they cannot serve both light fills in
    /// dark mode and dark fills in light mode.
    private func textColor(on fill: Color) -> Color {
        let background = ChartColorMath.RGB(fill.resolve(in: environment))
        let white = ChartColorMath.RGB(red: 1, green: 1, blue: 1)
        let ink = ChartColorMath.RGB(red: 0, green: 0, blue: 0)
        return ChartColorMath.contrast(white, background)
            >= ChartColorMath.contrast(ink, background) ? .white : Self.ink
    }

    /// Near-black, for labels on light fills.
    private static let ink = Color.black.opacity(0.85)

    private func label(_ point: ChartPoint, total: Double) -> String {
        var parts = [point.xLabel]
        if input.data.hasSeries, !point.series.isEmpty { parts.append(point.series) }
        parts.append(input.data.text(point.y))
        if total > 0 {
            parts.append(ChartValueFormat.percent.axisString(point.y / total * 100))
        }
        return parts.joined(separator: ", ")
    }
}
