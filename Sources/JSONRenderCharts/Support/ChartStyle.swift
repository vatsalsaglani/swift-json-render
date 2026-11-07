public import Charts
public import JSONRenderSwiftUI
public import SwiftUI

/// What a chart style receives: the resolved data, the drawn y domain, the selection, the
/// tokens and the default plot.
///
/// A style replaces or decorates the plot area. The title, caption, empty state,
/// accessibility descriptor, "Show as Table" and the selection write-back stay in the
/// component, so a style never changes what the chart means.
public struct ChartStyleConfiguration {
    public let kind: ChartKind
    public let data: ChartData
    /// The y domain the default plot uses (monotonic while streaming).
    public let yDomain: ClosedRange<Double>
    /// The selected x value or slice label.
    public let selection: Binding<String?>
    public let tokens: ChartTokens
    /// The default plot, with marks, axes and selection.
    public let marks: AnyView
    public let isStreaming: Bool
}

/// A chart style: one protocol for every chart. Register it for one chart type with
/// `.jrChartStyle(_:for:)`; `configuration.kind` says which chart calls it.
///
/// A style with stored properties should be `Equatable`, so that a changed value reaches
/// the charts; two values of a non-`Equatable` style type count as equal.
public protocol ChartStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: ChartStyleConfiguration) -> Body
}

/// The default style: the default plot.
public struct DefaultChartStyle: ChartStyle, Equatable {
    public init() {}

    public func makeBody(configuration: ChartStyleConfiguration) -> some View {
        configuration.marks
    }
}

/// A type-erased chart style.
struct AnyChartStyle: Sendable {
    let make: @MainActor @Sendable (ChartStyleConfiguration) -> AnyView
    let isEqual: @Sendable (AnyChartStyle) -> Bool
    let base: any Sendable

    init<S: ChartStyle>(_ style: S) {
        base = style
        make = { configuration in AnyView(style.makeBody(configuration: configuration)) }
        isEqual = { other in
            guard let other = other.base as? S else { return false }
            if let equatable = style as? any Equatable {
                return AnyChartStyle.equal(equatable, other)
            }
            return true
        }
    }

    private static func equal<T: Equatable>(_ lhs: T, _ rhs: Any) -> Bool {
        (rhs as? T) == lhs
    }
}

/// A type-erased mark override: builds a `Chart` from the data.
struct AnyChartMarks: Sendable {
    let make: @MainActor @Sendable (ChartData) -> AnyView
    let contentType: ObjectIdentifier
}

/// The chart styles and mark overrides in effect, one environment value for all charts.
public struct ChartStyleSet: Sendable, Equatable {
    var styles: [ChartKind: AnyChartStyle] = [:]
    var marks: [ChartKind: AnyChartMarks] = [:]

    public init() {}

    /// `true` when a style is set for `kind`.
    public func hasStyle(for kind: ChartKind) -> Bool { styles[kind] != nil }

    /// `true` when a mark override is set for `kind`.
    public func hasMarks(for kind: ChartKind) -> Bool { marks[kind] != nil }

    public static func == (lhs: ChartStyleSet, rhs: ChartStyleSet) -> Bool {
        guard Set(lhs.styles.keys) == Set(rhs.styles.keys),
            Set(lhs.marks.keys) == Set(rhs.marks.keys)
        else { return false }
        for (kind, style) in lhs.styles {
            guard let other = rhs.styles[kind], style.isEqual(other) else { return false }
        }
        for (kind, mark) in lhs.marks where rhs.marks[kind]?.contentType != mark.contentType {
            return false
        }
        return true
    }
}

extension EnvironmentValues {
    /// The chart styles and mark overrides. Set with `.jrChartStyle` and `.jrChartMarks`.
    @Entry public var jrChartStyles: ChartStyleSet = ChartStyleSet()
}

extension View {
    /// Uses `style` for every chart of type `kind` below this view.
    public func jrChartStyle<S: ChartStyle>(_ style: S, for kind: ChartKind) -> some View {
        transformEnvironment(\.jrChartStyles) { set in
            set.styles[kind] = AnyChartStyle(style)
        }
    }

    /// Uses `style` for every chart type in `kinds`.
    public func jrChartStyle<S: ChartStyle>(_ style: S, for kinds: [ChartKind]) -> some View {
        transformEnvironment(\.jrChartStyles) { set in
            for kind in kinds { set.styles[kind] = AnyChartStyle(style) }
        }
    }

    /// Replaces only the marks of charts of type `kind`. The chart keeps its data handling,
    /// domain, axes, selection, accessibility and chrome.
    ///
    /// The closure must depend on `data` only: two overrides with the same content type
    /// count as equal, so captured values that change do not reach the charts.
    public func jrChartMarks<Content: ChartContent>(
        for kind: ChartKind,
        @ChartContentBuilder _ content: @escaping @MainActor @Sendable (ChartData) -> Content
    ) -> some View {
        transformEnvironment(\.jrChartStyles) { set in
            set.marks[kind] = AnyChartMarks(
                make: { data in AnyView(Chart { content(data) }) },
                contentType: ObjectIdentifier(Content.self))
        }
    }
}
