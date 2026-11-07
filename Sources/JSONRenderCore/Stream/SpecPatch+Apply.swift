// Owner: jr-2 (wave 2).

/// RFC 6902 patch application with the upstream streaming tolerance
/// (`applySpecStreamPatch` in `types.ts`).
///
/// - `add` inserts into arrays (`-` appends) and sets object members.
/// - `replace` sets the value even when the target is absent (upstream tolerance).
/// - `remove` of an absent path is a no-op.
/// - `move` and `copy` without `from` are no-ops.
/// - `test` compares deeply; a mismatch throws `patchFailed(reason: "test mismatch")`.
/// - A `value` of `nil` (upstream `undefined`) on `add` or `replace` deletes an object member
///   (JSON output omits an `undefined` member, as upstream) and is refused in an array
///   (upstream would write a hole that JSON prints as `null`).
/// - A refused write (`__proto__`, the root pointer, an index past the array end, a write
///   through a scalar) throws `patchFailed`. Upstream ignores these silently; the result is
///   the same, and the journal records why.
/// - A write that would nest the document deeper than `JSONValue.maxDecodeDepth` throws
///   `patchFailed(reason: "too deep")`, so later recursive operations stay bounded.
extension JSONValue {
    /// Applies `patch`. `index` is the patch number the error reports.
    public mutating func apply(_ patch: SpecPatch, index: Int = 0) throws(StreamError) {
        func failure(_ reason: String) -> StreamError {
            .patchFailed(index: index, op: patch.op, path: patch.path, reason: reason)
        }
        guard let path = try? JSONPointer(patch.path) else { throw failure("invalid path") }
        switch patch.op {
        case .add:
            try write(patch.value, at: path, insert: true, failure: failure)
        case .replace:
            try write(patch.value, at: path, insert: false, failure: failure)
        case .remove:
            if path.isRoot { throw failure("invalid path") }
            remove(at: path)
        case .move:
            guard let fromString = patch.from else { return }
            guard let from = try? JSONPointer(fromString) else { throw failure("invalid path") }
            let moved = value(at: from)
            var attempt = self
            attempt.remove(at: from)
            try attempt.write(moved, at: path, insert: true, failure: failure)
            self = attempt
        case .copy:
            guard let fromString = patch.from else { return }
            guard let from = try? JSONPointer(fromString) else { throw failure("invalid path") }
            try write(value(at: from), at: path, insert: true, failure: failure)
        case .test:
            guard value(at: path) == patch.value else { throw failure("test mismatch") }
        }
    }

    private mutating func write(
        _ value: JSONValue?, at path: JSONPointer, insert: Bool,
        failure: (String) -> StreamError
    ) throws(StreamError) {
        guard JSONValue.isWritable(path) else { throw failure("invalid path") }
        guard let value else {
            if let parent = path.parent, case .array? = self.value(at: parent) {
                throw failure("undefined value in array")
            }
            remove(at: path)
            return
        }
        if value.nests(deeperThan: JSONValue.maxDecodeDepth - path.tokens.count) {
            throw failure("too deep")
        }
        let written = insert ? add(value, at: path) : set(value, at: path)
        if !written { throw failure("refused") }
    }

    /// `true` when the value has more than `limit` levels of containers. Iterative, so a
    /// value built in code with any depth is safe to check.
    func nests(deeperThan limit: Int) -> Bool {
        var stack: [(JSONValue, Int)] = [(self, 0)]
        while let (node, depth) = stack.popLast() {
            switch node {
            case .array(let items):
                if depth + 1 > limit { return true }
                for item in items where item.isContainer { stack.append((item, depth + 1)) }
            case .object(let members):
                if depth + 1 > limit { return true }
                for member in members.values where member.isContainer {
                    stack.append((member, depth + 1))
                }
            default:
                break
            }
        }
        return false
    }

    /// An over-estimate of the encoded JSON size in bytes. Iterative.
    var estimatedByteCount: Int {
        var total = 0
        var stack: [JSONValue] = [self]
        while let node = stack.popLast() {
            switch node {
            case .null: total += 4
            case .bool: total += 5
            case .number: total += 24
            case .string(let text): total += text.utf8.count * 2 + 2
            case .array(let items):
                total += 2 + items.count
                stack.append(contentsOf: items)
            case .object(let members):
                total += 2
                for (key, member) in members {
                    total += key.utf8.count * 2 + 4
                    stack.append(member)
                }
            }
        }
        return total
    }
}

/// Pure helpers with upstream names, for the parity suite and for hosts.
public enum SpecStreamCompiler {
    /// Upstream `compileSpecStream`: splits `text` into lines, applies every patch line to
    /// `initial` and returns the result, the applied patches and the journal.
    ///
    /// Deviation: upstream throws on a failed `test`; this journals the failure and goes on.
    /// A patch that throws is not in `patches`.
    public static func compile(_ text: String, initial: JSONValue = .object([:])) -> (
        result: JSONValue, patches: [SpecPatch], journal: [StreamError]
    ) {
        var decoder = SpecStreamDecoder(mode: .jsonl)
        var result = initial
        var patches: [SpecPatch] = []
        var journal: [StreamError] = []
        for event in decoder.push(text) + decoder.flush() {
            switch event {
            case .patch(let patch):
                do {
                    try result.apply(patch, index: patches.count)
                    patches.append(patch)
                } catch {
                    journal.append(error)
                }
            case .error(let error):
                journal.append(error)
            case .text:
                break
            }
        }
        return (result, patches, journal)
    }
}
