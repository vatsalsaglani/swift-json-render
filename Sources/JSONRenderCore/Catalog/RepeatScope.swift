/// One row of a `repeat`: the item, its index, and its absolute state path.
///
/// Nested repeats use `statePath: { "$item": "rows" }`, which resolves against the
/// enclosing row's `basePath`.
public struct RepeatScope: Sendable, Hashable {
    /// The array element for this row.
    public let item: JSONValue
    /// The row index.
    public let index: Int
    /// The absolute state path of this row, for example `/todos/0`.
    public let basePath: JSONPointer
    /// The value of the repeat `key` field for this row, when the repeat names one.
    public let key: String?

    public init(item: JSONValue, index: Int, basePath: JSONPointer, key: String? = nil) {
        self.item = item
        self.index = index
        self.basePath = basePath
        self.key = key
    }

    /// Upstream `resolveRepeatStatePath`.
    ///
    /// - An absolute path is returned as is (a path without a leading slash is read
    ///   leniently, like every upstream path). A path with `__proto__` gives `nil`.
    /// - `{ "$item": "" }` and `{ "$item": "/" }` give `enclosing`.
    /// - `{ "$item": "rows" }` gives `enclosing/rows`.
    /// - `{ "$item": … }` outside a repeat scope (`enclosing == nil`) gives `nil`.
    public static func resolveStatePath(_ path: RepeatStatePath, enclosing: JSONPointer?)
        -> JSONPointer?
    {
        switch path {
        case .absolute(let string):
            let pointer = JSONPointer(lenient: string)
            return pointer.containsForbiddenToken ? nil : pointer
        case .item(let relative):
            guard let enclosing else { return nil }
            if relative.isEmpty || relative == "/" { return enclosing }
            return enclosing.appending(relative: relative)
        }
    }

    /// Upstream `resolveRepeatItemStatePath`: the path of row `index` of the array at
    /// `statePath`.
    public static func itemStatePath(_ statePath: JSONPointer, index: Int) -> JSONPointer {
        statePath.appending(index: index)
    }
}
