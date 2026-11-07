// Owner: jr-2 (wave 2).

/// Splits a byte stream into lines on `\n` (byte 0x0A).
///
/// It works on UTF-8 bytes, not `Character`s: Swift reads `"\r\n"` as one `Character`, so a
/// split on the `Character` `"\n"` misses CRLF lines. Byte 0x0A never occurs inside a
/// multi-byte UTF-8 scalar, so a scalar split across two chunks waits in the buffer until its
/// line is complete.
///
/// A line longer than `limit` bytes is dropped and reported once as `.tooLong`, at the
/// newline that ends it, whatever the chunk boundaries were. The buffer never holds more than
/// `limit` bytes.
struct LineBuffer: Sendable {
    enum Piece: Sendable, Hashable {
        case line(String)
        case tooLong
    }

    let limit: Int
    private var pending: [UInt8] = []
    private var overlong = false

    init(limit: Int) {
        self.limit = limit
    }

    var bufferedBytes: Int { pending.count }

    /// Appends `bytes` and returns every line it completes.
    mutating func append(_ bytes: some Collection<UInt8>) -> [Piece] {
        var pieces: [Piece] = []
        var start = bytes.startIndex
        var index = bytes.startIndex
        while index != bytes.endIndex {
            if bytes[index] == 0x0A {
                pieces.append(complete(bytes[start..<index]))
                start = bytes.index(after: index)
            }
            index = bytes.index(after: index)
        }
        let rest = bytes[start...]
        if !overlong {
            if pending.count + rest.count > limit {
                overlong = true
                pending.removeAll()
            } else {
                pending.append(contentsOf: rest)
            }
        }
        return pieces
    }

    /// The unterminated remainder, if any, and an empty buffer.
    mutating func drain() -> Piece? {
        defer {
            pending.removeAll()
            overlong = false
        }
        if overlong { return .tooLong }
        if pending.isEmpty { return nil }
        return .line(String(decoding: pending, as: UTF8.self))
    }

    private mutating func complete(_ tail: some Collection<UInt8>) -> Piece {
        defer {
            pending.removeAll(keepingCapacity: true)
            overlong = false
        }
        if overlong || pending.count + tail.count > limit { return .tooLong }
        if pending.isEmpty { return .line(String(decoding: tail, as: UTF8.self)) }
        pending.append(contentsOf: tail)
        return .line(String(decoding: pending, as: UTF8.self))
    }
}
