import Foundation
import Testing

@testable import JSONRenderCore

/// One row of `upstream/streams/index.json` or `streams/index.json`.
struct StreamCase: Sendable, CustomTestStringConvertible {
    let name: String
    let kind: String
    /// The raw input text, byte-exact.
    let input: String
    /// The expected-result document (upstream) or the `expect` object (own fixtures).
    let expected: JSONValue

    var testDescription: String { "\(kind)/\(name)" }
}

/// Loads the stream fixtures, located from this file's path.
enum StreamFixtures {
    static let upstreamRoot = ParityFixtures.url("streams")
    static let ownRoot: URL = ParityFixtures.root
        .deletingLastPathComponent()  // upstream
        .appendingPathComponent("streams")

    /// The 33 upstream cases, in index order.
    static let upstream: [StreamCase] = load(upstreamRoot, ownFormat: false)

    /// The cases this package adds (`Tests/ParityFixtures/streams`).
    static let own: [StreamCase] = load(ownRoot, ownFormat: true)

    static func upstream(kind: String) -> [StreamCase] {
        upstream.filter { $0.kind == kind }
    }

    /// Every `.jsonl` and `mixed/*.txt` input, upstream and own, for the fuzz suites.
    static var transcripts: [StreamCase] {
        upstream + own.filter { $0.name != "object-mode-fragments" }
    }

    private static func load(_ root: URL, ownFormat: Bool) -> [StreamCase] {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("index.json")),
            case .array(let rows)? = try? JSONDecoder().decode(JSONValue.self, from: data)
        else { return [] }
        return rows.compactMap { row in
            guard case .string(let name)? = row["name"], case .string(let input)? = row["input"],
                let inputData = try? Data(contentsOf: root.appendingPathComponent(input))
            else { return nil }
            let expected: JSONValue?
            if ownFormat {
                expected = row["expect"]
            } else if case .string(let file)? = row["expected"],
                let expectedData = try? Data(contentsOf: root.appendingPathComponent(file))
            {
                expected = try? JSONDecoder().decode(JSONValue.self, from: expectedData)
            } else {
                expected = nil
            }
            guard let expected else { return nil }
            return StreamCase(
                name: name,
                kind: row["kind"]?.stringValue ?? (input.hasSuffix(".txt") ? "mixed" : "own"),
                input: String(decoding: inputData, as: UTF8.self), expected: expected)
        }
    }
}

/// A fixture `{ op, path, value?, from? }` as a `SpecPatch`.
func fixturePatch(_ json: JSONValue) -> SpecPatch? {
    guard case .string(let opName)? = json["op"], let op = PatchOperation(rawValue: opName),
        case .string(let path)? = json["path"]
    else { return nil }
    return SpecPatch(op: op, path: path, value: json["value"], from: json["from"]?.stringValue)
}

/// The decoded events of a mixed fixture as `{ kind, value }` objects.
func fixtureEvents(_ events: [SpecStreamEvent]) -> [JSONValue] {
    events.compactMap { event in
        switch event {
        case .patch(let patch):
            var members: [String: JSONValue] = [
                "op": .string(patch.op.rawValue), "path": .string(patch.path),
            ]
            if let value = patch.value { members["value"] = value }
            if let from = patch.from { members["from"] = .string(from) }
            return ["kind": "patch", "value": .object(members)]
        case .text(let text):
            return ["kind": "text", "value": .string(text)]
        case .error:
            return nil
        }
    }
}

/// A fixed-seed SplitMix64, so a fuzz failure reproduces.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
