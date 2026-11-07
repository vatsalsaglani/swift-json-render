// Owner: jr-3b (wave 2). Table: rows of text cells, from `rows` or from a `repeat`.
internal import Foundation
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// One column. `key` reads a field of a row object (repeat rows); `label` is the header.
public struct JRTableColumn: Sendable, Hashable, Identifiable {
    public let key: String
    public let label: String
    /// `true` when the column holds numbers: right-aligned, tabular digits.
    public let isNumeric: Bool
    public var id: String { key }
}

/// One row: the cell texts in column order and, for repeat rows, the row's children
/// (drawn in a trailing column under the row's scope).
public struct JRTableRow: Identifiable {
    public let id: String
    public let cells: [String]
    public let actions: JRStyleContent?
}

/// The sort order of a sortable table (view state; it never writes spec state).
public struct JRTableSort: Sendable, Hashable {
    public var column: String
    public var ascending: Bool

    public init(column: String, ascending: Bool) {
        self.column = column
        self.ascending = ascending
    }
}

/// What a table style receives. `rows` are already sorted. `sort` is `nil` unless the
/// spec sets `sortable`. `empty` is the `empty` slot (or `nil`).
public struct JRTableStyleConfiguration {
    public let columns: [JRTableColumn]
    /// At most `SpecLimits.maxRepeatRows` rows (500 by default).
    public let rows: [JRTableRow]
    /// The rows in the data. More than `rows.count` when the row cap cut the rest; the
    /// Table then draws "Showing 500 of N rows" below the style's body.
    public let totalRows: Int
    public let caption: String?
    public let sort: Binding<JRTableSort?>?
    public let empty: JRStyleContent?
    public let hasActions: Bool
    public let theme: JSONRenderTheme
}

/// Restyles every Table in a subtree.
public protocol JRTableStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRTableStyleConfiguration) -> Body
}

/// The default table: a full-width hairline box, a quiet header, hairlines between rows, no fill
/// stripes; number columns right-aligned with tabular digits; the caption below.
public struct DefaultJRTableStyle: JRTableStyle {
    public init() {}

    public func makeBody(configuration: JRTableStyleConfiguration) -> some View {
        DefaultTableBody(configuration: configuration)
    }
}

private struct DefaultTableBody: View {
    let configuration: JRTableStyleConfiguration

    var body: some View {
        let theme = configuration.theme
        VStack(alignment: .leading, spacing: theme.space.s2) {
            Grid(alignment: .leading, horizontalSpacing: theme.space.s4, verticalSpacing: 0) {
                header
                Divider().gridCellUnsizedAxes(.horizontal)
                if configuration.rows.isEmpty {
                    emptyRow
                } else {
                    ForEach(Array(configuration.rows.enumerated()), id: \.element.id) {
                        position, row in
                        if position > 0 { Divider().gridCellUnsizedAxes(.horizontal) }
                        rowView(row)
                    }
                }
            }
            .padding(.horizontal, theme.space.s3)
            .padding(.vertical, theme.space.s1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .standardHairline(theme, radius: theme.radius.field)
            if let caption = configuration.caption {
                Text(caption)
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var header: some View {
        let theme = configuration.theme
        return GridRow {
            ForEach(configuration.columns) { column in
                headerCell(column)
                    .gridColumnAlignment(column.isNumeric ? .trailing : .leading)
            }
            if configuration.hasActions {
                Text("").accessibilityHidden(true)
            }
        }
        .font(theme.type.footnote.weight(theme.type.weights.semibold))
        .foregroundStyle(theme.color.textSecondary)
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func headerCell(_ column: JRTableColumn) -> some View {
        if let sort = configuration.sort {
            let active = sort.wrappedValue?.column == column.key
            Button {
                let ascending = active ? !(sort.wrappedValue?.ascending ?? true) : true
                sort.wrappedValue = JRTableSort(column: column.key, ascending: ascending)
            } label: {
                HStack(spacing: 3) {
                    Text(column.label)
                    if active {
                        Image(
                            systemName: sort.wrappedValue?.ascending ?? true
                                ? "chevron.up" : "chevron.down"
                        )
                        .font(.system(size: 8, weight: .bold))
                    }
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(configuration.theme.color.textSecondary)
            .accessibilityLabel(Text("Sort by \(column.label)"))
            .accessibilityValue(
                Text(
                    active
                        ? ((sort.wrappedValue?.ascending ?? true) ? "Ascending" : "Descending")
                        : ""))
        } else {
            Text(column.label)
        }
    }

    private func rowView(_ row: JRTableRow) -> some View {
        let theme = configuration.theme
        return GridRow {
            ForEach(Array(configuration.columns.enumerated()), id: \.element.id) {
                index, column in
                let text = index < row.cells.count ? row.cells[index] : ""
                Text(text)
                    .font(column.isNumeric ? theme.type.body.monospacedDigit() : theme.type.body)
                    .foregroundStyle(theme.color.text)
                    .fixedSize(horizontal: false, vertical: true)
                    // Text columns share the free width; number columns keep their width.
                    .frame(
                        maxWidth: column.isNumeric ? nil : .infinity,
                        alignment: column.isNumeric ? .trailing : .leading)
            }
            if configuration.hasActions {
                HStack(spacing: theme.space.s1) {
                    if let actions = row.actions { actions }
                }
                .gridColumnAlignment(.trailing)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(rowLabel(row)))
    }

    private var emptyRow: some View {
        let theme = configuration.theme
        return HStack {
            if let empty = configuration.empty {
                empty
            } else {
                Text("No rows").font(theme.type.body).foregroundStyle(theme.color.textSecondary)
            }
        }
        .padding(.vertical, theme.space.s3)
        .gridCellColumns(max(configuration.columns.count + (configuration.hasActions ? 1 : 0), 1))
    }

    /// "Service API Gateway, Status Operational, …" for VoiceOver.
    private func rowLabel(_ row: JRTableRow) -> String {
        zip(configuration.columns, row.cells).map { "\($0.label) \($1)" }
            .joined(separator: ", ")
    }
}

extension EnvironmentValues {
    /// The table style. Default: `DefaultJRTableStyle`.
    @Entry public var jrTableStyle: any JRTableStyle = DefaultJRTableStyle()
}

extension View {
    /// Sets the style of every Table in this subtree.
    public func jrTableStyle(_ style: some JRTableStyle) -> some View {
        environment(\.jrTableStyle, style)
    }
}

/// `Table`: upstream shadcn props, plus:
/// - `repeat` on the Table: one row per item; `columns` name item fields (a string is the
///   key and the header; `{ key, label }` sets both); the Table's children render once
///   per row in a trailing column, under that row's scope (`$item`, `$index`).
/// - `rows` may hold objects; cells then read the column keys.
/// - `sortable`: header buttons sort the drawn rows (view state only).
/// - the `empty` slot replaces "No rows"; the `loading` slot replaces the streaming
///   placeholder.
/// - literal `rows` past `SpecLimits.maxRepeatRows` (500) are not drawn, as `repeat` rows:
///   a caption says "Showing 500 of N rows" and the render model records `tooManyRows`.
@JRComponent(
    "Table",
    description:
        "Data table. columns: header labels. rows: 2D array of cell strings, e.g. [[\"Alice\",\"admin\"],[\"Bob\",\"user\"]].",
    slots: ["default", "empty", "loading"])
public struct JRTable: View {
    @JRProp var columns: [JSONValue]
    @JRProp var rows: [JSONValue]
    @JRProp var caption: String?
    @JRProp(description: "Let the user sort rows by a column header.") var sortable: Bool?

    @State private var sort: JRTableSort?
    @Environment(\.jrTableStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrRepeatRows) private var inheritedRows
    @Environment(\.jrRenderModel) private var renderModel

    /// The definition with `columns` and `rows` spelled out as upstream prints them.
    nonisolated static var catalogDefinition: ComponentDefinition {
        definition.replacingProps([
            ("columns", StandardSchemas.stringList), ("rows", StandardSchemas.stringRows),
        ])
    }

    public var body: some View {
        // Named-slot children of a repeat element inherit its rows: use them only when they
        // belong to this Table.
        let repeatRows = inheritedRows.flatMap { $0.elementID == jrContext.id ? $0 : nil }
        let model = JRTableModel(
            columns: columns, rows: rows, repeatRows: repeatRows,
            maxRows: renderModel?.limits.maxRepeatRows ?? SpecLimits.defaultMaxRepeatRows)
        // `record` does not publish, so it is safe during a view update.
        let _ =
            model.isTruncated
            ? renderModel?.record(.tooManyRows(id: jrContext.id, count: model.totalRows)) : nil
        let sorted = model.sorted(by: (sortable ?? false) ? sort : nil)
        if jrContext.isStreaming, model.columns.isEmpty, sorted.isEmpty {
            if let loading = jrContext.slot(JRSlots.loading) {
                loading
            } else {
                JRSkeletonPlaceholder(shape: .tableBody, fillsWidth: true)
            }
        } else {
            let tableRows = sorted.map { row in
                JRTableRow(
                    id: row.id, cells: row.cells,
                    actions: row.childIDs.isEmpty
                        ? nil : JRStyleContent(JRChildren(ids: row.childIDs)))
            }
            let configuration = JRTableStyleConfiguration(
                columns: model.columns, rows: tableRows, totalRows: model.totalRows,
                caption: caption.flatMap { $0.isEmpty ? nil : $0 },
                sort: (sortable ?? false) ? $sort : nil,
                empty: jrContext.slot(JRSlots.empty).map { JRStyleContent($0) },
                hasActions: sorted.contains { !$0.childIDs.isEmpty }, theme: theme)
            VStack(alignment: .leading, spacing: theme.space.s2) {
                JRStyleContent(style.makeBody(configuration: configuration))
                // Outside the style, so every style shows that rows are missing.
                if let footer = model.footer {
                    Text(footer)
                        .font(theme.type.caption)
                        .foregroundStyle(theme.color.textSecondary)
                }
                // Children of a Table without `repeat` are not row actions: draw them below.
                if repeatRows == nil, !jrContext.children.isEmpty {
                    jrContext.children
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(caption ?? "Table"))
        }
    }
}

/// Columns and rows of a Table, pure (no SwiftUI state) so tests can use it.
struct JRTableModel {
    struct Row: Equatable {
        let id: String
        let cells: [String]
        let childIDs: [String]
    }

    let columns: [JRTableColumn]
    /// At most `maxRows` rows.
    let rows: [Row]
    /// The rows in the data before the cap (repeat rows are capped upstream of the Table, by
    /// `ElementResolution.repeatRows`).
    let totalRows: Int

    /// `maxRows` caps literal `rows` (the spec's `maxRepeatRows`, 500 by default).
    init(
        columns rawColumns: [JSONValue], rows rawRows: [JSONValue], repeatRows: JRRepeatRows?,
        maxRows: Int = SpecLimits.defaultMaxRepeatRows
    ) {
        var seen: Set<String> = []
        let specs: [(key: String, label: String, align: String?)] = rawColumns.compactMap {
            column in
            let entry: (String, String, String?)?
            switch column {
            case .string(let name): entry = (name, name, nil)
            case .object(let fields):
                let key = fields["key"]?.stringValue ?? fields["label"]?.stringValue
                entry = key.map {
                    ($0, fields["label"]?.stringValue ?? $0, fields["align"]?.stringValue)
                }
            default: entry = nil
            }
            guard let entry, seen.insert(entry.0).inserted else { return nil }
            return entry
        }
        let rows: [Row]
        if let repeatRows {
            totalRows = repeatRows.scopes.count
            rows = repeatRows.scopes.indices.map { position in
                let scope = repeatRows.scopes[position]
                return Row(
                    id: "i:\(position)",
                    cells: specs.map { JRTableModel.cell(scope.item[$0.key]) },
                    childIDs: repeatRows.ids(forRow: position))
            }
        } else {
            totalRows = rawRows.count
            rows = rawRows.prefix(max(maxRows, 0)).enumerated().map { index, raw in
                let cells: [String]
                switch raw {
                case .array(let values): cells = values.map { JRTableModel.cell($0) }
                case .object(let fields): cells = specs.map { JRTableModel.cell(fields[$0.key]) }
                default: cells = [JRTableModel.cell(raw)]
                }
                return Row(id: "i:\(index)", cells: cells, childIDs: [])
            }
        }
        self.rows = rows
        self.columns = specs.enumerated().map { index, spec in
            let values = rows.compactMap { index < $0.cells.count ? $0.cells[index] : nil }
                .filter { !$0.isEmpty }
            let numeric =
                spec.align == "right"
                || (spec.align == nil && !values.isEmpty
                    && values.allSatisfy { JRTableModel.number($0) != nil })
            return JRTableColumn(key: spec.key, label: spec.label, isNumeric: numeric)
        }
    }

    /// `true` when the cap cut rows.
    var isTruncated: Bool { totalRows > rows.count }

    /// "Showing 500 of 1200 rows" when the cap cut rows, else `nil`.
    var footer: String? {
        isTruncated ? "Showing \(rows.count) of \(totalRows) rows" : nil
    }

    /// A scalar as text (JavaScript `String(v)`); `null`, missing, objects and arrays are
    /// empty.
    static func cell(_ value: JSONValue?) -> String {
        switch value {
        case .string(let text)?: text
        case .number?, .bool?: value?.jsString ?? ""
        default: ""
        }
    }

    /// The number a cell shows, or `nil`: optional sign, `$`/`€`/`£`, grouping commas and a
    /// trailing `%` are allowed ("1,284", "99.9%", "-3", "$12.50"). "12ms" is not a number.
    static func number(_ text: String) -> Double? {
        var body = text.trimmingCharacters(in: .whitespaces)
        if body.hasSuffix("%") { body.removeLast() }
        var sign = 1.0
        if let first = body.first, first == "-" || first == "+" || first == "\u{2212}" {
            sign = first == "+" ? 1 : -1
            body.removeFirst()
        }
        if let first = body.first, "$€£".contains(first) { body.removeFirst() }
        body = body.replacingOccurrences(of: ",", with: "")
        guard !body.isEmpty, body.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }),
            let value = Double(body)
        else { return nil }
        return sign * value
    }

    /// The rows in `sort` order (stable); numbers compare as numbers when both cells are
    /// numbers, else text compares with the Finder's order.
    func sorted(by sort: JRTableSort?) -> [Row] {
        guard let sort, let index = columns.firstIndex(where: { $0.key == sort.column }) else {
            return rows
        }
        let keyed = rows.enumerated().map { ($0.offset, $0.element) }
        return keyed.sorted { lhs, rhs in
            let a = index < lhs.1.cells.count ? lhs.1.cells[index] : ""
            let b = index < rhs.1.cells.count ? rhs.1.cells[index] : ""
            let order: ComparisonResult
            if let x = JRTableModel.number(a), let y = JRTableModel.number(b) {
                order = x < y ? .orderedAscending : (x > y ? .orderedDescending : .orderedSame)
            } else {
                order = a.localizedStandardCompare(b)
            }
            if order == .orderedSame { return lhs.0 < rhs.0 }
            return sort.ascending ? order == .orderedAscending : order == .orderedDescending
        }.map(\.1)
    }
}
