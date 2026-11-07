import Foundation

// Owner: jr-2 (wave 2).

/// Turns streamed text into `SpecStreamEvent`s. A value type: one decoder per stream.
///
/// Modes:
/// - `.jsonl`: upstream `createSpecStreamCompiler`. One patch per line. A non-blank line that
///   is not a patch gives `.error(.badLine)` and the stream goes on (upstream skips it
///   silently; the final result is the same).
/// - `.mixed`: upstream `createMixedStreamParser`. Text lines and patch lines, with the
///   optional ```` ```spec ```` fence. Outside the fence, a line that is not a patch is
///   `.text` (prose, and a JSON object without a string `op`, as upstream). A JSON object
///   with a string `op` that is not a valid patch (an unknown `op`, no `path`) is a bad
///   patch, not prose: it gives `.error(.badLine)`, inside or outside the fence. Other lines
///   in the fence that are not patches are dropped silently, as upstream.
/// - `.object`: one JSON spec document that arrives in pieces (for example function-call
///   argument deltas). No upstream equivalent. See `push(_:)`.
///
/// Line indexes are 0-based and count every line, blank lines included. Error reasons are a
/// fixed vocabulary ("not an object", "no op/path", "invalid JSON", "line too long",
/// "document was not closed"); the decoder never reports or logs stream text.
public struct SpecStreamDecoder: Sendable {
    public enum Mode: Sendable, Hashable {
        case jsonl, object, mixed
    }

    /// The largest accepted buffer (64 KiB). `init` clamps `bufferLimit` to it.
    public static let maxBufferLimit = 64 * 1024

    public let mode: Mode
    /// For `.jsonl` and `.mixed`: the longest line. For `.object`: the whole document.
    public let bufferLimit: Int

    private var lines: LineBuffer
    private var inFence = false
    private var lineCount = 0
    private var document: [UInt8] = []
    private var documentFailed = false
    private var emitted: [String: JSONValue] = [:]

    public init(mode: Mode, bufferLimit: Int = SpecStreamDecoder.maxBufferLimit) {
        self.mode = mode
        self.bufferLimit = min(max(bufferLimit, 1), SpecStreamDecoder.maxBufferLimit)
        lines = LineBuffer(limit: self.bufferLimit)
    }

    /// The lines seen so far.
    public var lineIndex: Int { lineCount }

    /// The bytes held for an incomplete line or document.
    public var bufferedBytes: Int {
        mode == .object ? document.count : lines.bufferedBytes
    }

    /// Decodes a chunk of text.
    ///
    /// In `.object` mode the whole buffer is parsed tolerantly on each push: an open string,
    /// array or object is closed, and a trailing partial token (`tru`, `12.`, a key with no
    /// value, a trailing comma) is dropped. Then `/root`, `/state` and each
    /// `/elements/<id>` that changed is emitted as one `add` or `replace` patch, never deeper.
    /// A part is emitted only when it is complete in the buffer (its closing quote or brace
    /// has arrived), so it never flaps; an element is emitted only when it has a string
    /// `type`. Past `bufferLimit` bytes the decoder reports `.unrecoverable("buffer limit")`
    /// once and ignores later pushes. Bytes that no continuation can make valid JSON (a
    /// definite syntax error, not a cut) report `.unrecoverable("invalid JSON")` at once;
    /// later pushes and `flush()` then return nothing.
    public mutating func push(_ text: String) -> [SpecStreamEvent] {
        push(bytes: text.utf8)
    }

    /// Decodes a chunk of UTF-8 bytes. A scalar split across two chunks is safe: lines are
    /// cut on byte 0x0A, and `.object` mode ignores an incomplete trailing scalar until the
    /// rest arrives.
    public mutating func push(bytes: some Collection<UInt8>) -> [SpecStreamEvent] {
        switch mode {
        case .jsonl, .mixed:
            return lines.append(bytes).flatMap { process($0) }
        case .object:
            guard !documentFailed else { return [] }
            if document.count + bytes.count > bufferLimit {
                documentFailed = true
                document = []
                return [.error(.unrecoverable("buffer limit"))]
            }
            document.append(contentsOf: bytes)
            let parsed = TolerantJSON.parse(document[..<TolerantJSON.completeUTF8Prefix(document)])
            guard let value = parsed.value else {
                // No value and no cut: the bytes are not a JSON prefix. More bytes cannot
                // repair them, so fail now instead of waiting for `flush`.
                guard parsed.cutPath == nil else { return [] }
                documentFailed = true
                document = []
                return [.error(.unrecoverable("invalid JSON"))]
            }
            return diff(value, cutPath: parsed.cutPath)
        }
    }

    /// Ends the stream: decodes what is left in the buffer and empties it.
    ///
    /// In `.object` mode the document is parsed strictly first. When that fails, the tolerant
    /// result is used and `.badLine(index: 0, reason: "document was not closed")` is added.
    public mutating func flush() -> [SpecStreamEvent] {
        switch mode {
        case .jsonl, .mixed:
            guard let piece = lines.drain() else { return [] }
            return process(piece)
        case .object:
            guard !documentFailed else { return [] }
            defer { document = [] }
            if document.allSatisfy(TolerantJSON.isWhitespace) { return [] }
            if let value = try? JSONDecoder().decode(JSONValue.self, from: Data(document)) {
                return diff(value, cutPath: nil)
            }
            let parsed = TolerantJSON.parse(document[...])
            guard let value = parsed.value else {
                return [.error(.badLine(index: 0, reason: "invalid JSON"))]
            }
            return diff(value, cutPath: nil) + [
                .error(.badLine(index: 0, reason: "document was not closed"))
            ]
        }
    }

    /// Upstream `parseSpecStreamLine`: the trimmed line starts with `{`, parses as JSON, and
    /// has a known string `op` and a string `path`.
    public static func parseLine(_ line: String) -> Result<SpecPatch, LineError> {
        switch attempt(line) {
        case .patch(let patch): .success(patch)
        case .notAnObject: .failure(.notAnObject)
        case .invalidJSON: .failure(.invalidJSON)
        case .noOp, .badPatch: .failure(.noOpOrPath)
        }
    }

    /// What one line is, with the `.noOpOrPath` failure split in two for `.mixed` mode.
    private enum LineAttempt {
        case patch(SpecPatch)
        case notAnObject, invalidJSON
        /// A JSON object without a string `op`: upstream treats it as text.
        case noOp
        /// A JSON object with a string `op` that is not a valid patch.
        case badPatch
    }

    private static func attempt(_ line: String) -> LineAttempt {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") else { return .notAnObject }
        guard let json = try? JSONDecoder().decode(JSONValue.self, from: Data(trimmed.utf8)),
            case .object(let members) = json
        else { return .invalidJSON }
        guard case .string(let opName)? = members["op"] else { return .noOp }
        guard let op = PatchOperation(rawValue: opName), case .string(let path)? = members["path"]
        else { return .badPatch }
        return .patch(
            SpecPatch(
                op: op, path: path, value: members["value"], from: members["from"]?.stringValue))
    }

    /// Why a line is not a patch.
    public enum LineError: String, Error, Sendable, Hashable {
        case notAnObject = "not an object"
        case invalidJSON = "invalid JSON"
        case noOpOrPath = "no op/path"
    }

    // MARK: - Lines

    private mutating func process(_ piece: LineBuffer.Piece) -> [SpecStreamEvent] {
        let index = lineCount
        lineCount += 1
        guard case .line(let line) = piece else {
            return [.error(.badLine(index: index, reason: "line too long"))]
        }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .jsonl:
            if trimmed.isEmpty { return [] }
            switch SpecStreamDecoder.parseLine(trimmed) {
            case .success(let patch): return [.patch(patch)]
            case .failure(let error):
                return [.error(.badLine(index: index, reason: error.rawValue))]
            }
        case .mixed:
            if !inFence, trimmed.hasPrefix("```spec") {
                inFence = true
                return []
            }
            if inFence, trimmed == "```" {
                inFence = false
                return []
            }
            if trimmed.isEmpty { return [] }
            switch SpecStreamDecoder.attempt(trimmed) {
            case .patch(let patch):
                return [.patch(patch)]
            case .badPatch:
                return [.error(.badLine(index: index, reason: LineError.noOpOrPath.rawValue))]
            case .notAnObject, .invalidJSON, .noOp:
                return inFence ? [] : [.text(line)]
            }
        case .object:
            return []
        }
    }

    // MARK: - Object mode

    /// Emits `/root`, `/state` and `/elements/<id>` when they changed and are complete.
    private mutating func diff(_ value: JSONValue, cutPath: [String]?) -> [SpecStreamEvent] {
        guard case .object(let top) = value else { return [] }
        func isComplete(_ path: [String]) -> Bool {
            guard let cutPath, cutPath.count >= path.count else { return true }
            return Array(cutPath.prefix(path.count)) != path
        }
        var candidates: [(path: [String], value: JSONValue)] = []
        if case .string? = top["root"], let root = top["root"] {
            candidates.append((["root"], root))
        }
        if case .object? = top["state"], let state = top["state"] {
            candidates.append((["state"], state))
        }
        if case .object(let elements)? = top["elements"] {
            for id in elements.keys.sorted() {
                guard let element = elements[id], case .string? = element["type"] else { continue }
                candidates.append((["elements", id], element))
            }
        }
        var events: [SpecStreamEvent] = []
        for candidate in candidates where isComplete(candidate.path) {
            let pointer = JSONPointer(tokens: candidate.path).description
            let previous = emitted[pointer]
            guard previous != candidate.value else { continue }
            emitted[pointer] = candidate.value
            events.append(
                .patch(
                    SpecPatch(
                        op: previous == nil ? .add : .replace, path: pointer, value: candidate.value
                    )))
        }
        return events
    }
}
