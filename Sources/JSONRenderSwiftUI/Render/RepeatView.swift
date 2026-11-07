// Owner: jr-3 (wave 2). Repeat rows: the element renders once, its children once per row.
public import JSONRenderCore
internal import SwiftUI

/// The rows of one `repeat` element and the child ids it hands its component.
///
/// The component receives `context.children` as row-major ids (row 0's children, then
/// row 1's, …). Each id encodes the row, so any container lays rows out with no change,
/// and SwiftUI identity follows the repeat `key` when the spec names one (else the index).
/// A component that lays rows out itself (a Table) reads `\.jrRepeatRows` and asks for
/// `ids(forRow:)`.
public struct JRRepeatRows: Sendable, Equatable {
    /// The repeat element.
    public let elementID: String
    /// One scope per row, in array order.
    public let scopes: [RepeatScope]
    /// The element's own child ids (one row's worth).
    public let childIDs: [String]
    private let tokens: [String]
    private let positions: [String: Int]

    public init(elementID: String, scopes: [RepeatScope], childIDs: [String]) {
        self.elementID = elementID
        self.scopes = scopes
        self.childIDs = childIDs
        var keyCounts: [String: Int] = [:]
        for scope in scopes { if let key = scope.key { keyCounts[key, default: 0] += 1 } }
        let tokens = scopes.map { scope in
            if let key = scope.key, keyCounts[key] == 1 { return "k:" + key }
            return "i:\(scope.index)"
        }
        self.tokens = tokens
        var positions: [String: Int] = [:]
        for (position, token) in tokens.enumerated() { positions[token] = position }
        self.positions = positions
    }

    /// Every row's child ids, row-major.
    public var flatIDs: [String] {
        scopes.indices.flatMap { ids(forRow: $0) }
    }

    /// The child ids of row `row` (a position in `scopes`).
    public func ids(forRow row: Int) -> [String] {
        guard tokens.indices.contains(row) else { return [] }
        let prefix =
            JRRepeatRows.marker + elementID + JRRepeatRows.separator + tokens[row]
            + JRRepeatRows.separator
        return childIDs.map { prefix + $0 }
    }

    /// The scope a row token names.
    func scope(forToken token: String) -> RepeatScope? {
        positions[token].map { scopes[$0] }
    }

    public static func == (lhs: JRRepeatRows, rhs: JRRepeatRows) -> Bool {
        lhs.elementID == rhs.elementID && lhs.childIDs == rhs.childIDs && lhs.scopes == rhs.scopes
    }

    static let marker = "\u{1E}"
    static let separator = "\u{1F}"

    /// A decoded row child id.
    struct RowChild: Hashable {
        let elementID: String
        let token: String
        let childID: String
    }

    /// Decodes an id made by `ids(forRow:)`; `nil` for a plain element id.
    static func parse(_ id: String) -> RowChild? {
        guard id.hasPrefix(marker) else { return nil }
        let parts = id.dropFirst(marker.count).split(
            separator: Character(separator), maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        return RowChild(
            elementID: String(parts[0]), token: String(parts[1]), childID: String(parts[2]))
    }
}

/// Renders one child of one repeat row in that row's scope.
struct RepeatRowView: View {
    let child: JRRepeatRows.RowChild
    @Environment(\.jrRepeatRows) private var rows

    var body: some View {
        if let rows, rows.elementID == child.elementID,
            let scope = rows.scope(forToken: child.token)
        {
            ElementView(id: child.childID)
                .environment(\.jrRepeatScope, scope)
                .environment(\.jrRepeatRows, nil)
        }
    }
}
