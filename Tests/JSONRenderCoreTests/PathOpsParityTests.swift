import Foundation
import Testing

@testable import JSONRenderCore

/// `upstream/state/*.json`: the path operations, repeat path helpers and
/// `flattenToPointers`, replayed op by op.
@Suite("Path ops parity (upstream/state)")
struct PathOpsParityTests {
    /// Cases not run, with the reason. Empty: jr-1b landed `findFormValue`.
    static let skipped: [String: String] = [:]

    static func runnable() -> [FixtureCase] {
        ParityFixtures.cases("state").filter { skipped[$0.name] == nil }
    }

    @Test("Every skipped case exists in the index")
    func skippedCasesExist() {
        let names = Set(ParityFixtures.cases("state").map(\.name))
        for name in Self.skipped.keys {
            #expect(names.contains(name), "Unknown skipped case \(name)")
        }
    }

    @Test("Replays the case", arguments: PathOpsParityTests.runnable())
    func replay(_ fixture: FixtureCase) throws {
        var state = fixture.value("initial") ?? .object([:])
        guard case .array(let ops)? = fixture.raw("ops") else {
            Issue.record("No ops")
            return
        }
        for (index, op) in ops.enumerated() {
            let kind = op["op"]?.stringValue ?? ""
            let path = op["path"]?.stringValue ?? ""
            let value = op["value"].flatMap(ParityFixtures.resolvingMarkers)
            let expect = op["expect"].flatMap(ParityFixtures.resolvingMarkers)
            switch kind {
            case "set":
                if let pointer = try? JSONPointer(path), let value { state.set(value, at: pointer) }
            case "add":
                if let pointer = try? JSONPointer(path), let value { state.add(value, at: pointer) }
            case "remove":
                if let pointer = try? JSONPointer(path) { state.remove(at: pointer) }
            case "get":
                #expect(state.value(at: JSONPointer(lenient: path)) == expect, "op \(index)")
            case "patch":
                let patch = op["patch"] ?? .null
                if let expectedError = op["throws"] {
                    do {
                        try PatchReplayer.apply(patch, to: &state)
                        Issue.record("op \(index) did not throw")
                    } catch {
                        if case .string(let message) = expectedError {
                            #expect(error.message == message, "op \(index)")
                        }
                    }
                } else {
                    try PatchReplayer.apply(patch, to: &state)
                }
            case "resolveRepeatStatePath":
                let raw = op["value"] ?? .null
                let statePath: RepeatStatePath =
                    raw.stringValue.map(RepeatStatePath.absolute)
                    ?? .item(raw["$item"]?.stringValue ?? "")
                let base = op["base"]?.stringValue.map { JSONPointer(lenient: $0) }
                let resolved = RepeatScope.resolveStatePath(statePath, enclosing: base)
                #expect(
                    resolved == expect?.stringValue.map { JSONPointer(lenient: $0) }, "op \(index)")
                #expect((resolved == nil) == (expect == nil), "op \(index)")
            case "resolveRepeatItemStatePath":
                let base = JSONPointer(lenient: op["base"]?.stringValue ?? "")
                let rowIndex = Int(op["index"]?.numberValue ?? -1)
                let resolved = RepeatScope.itemStatePath(base, index: rowIndex)
                #expect(resolved == JSONPointer(lenient: expect?.stringValue ?? "?"), "op \(index)")
            case "findFormValue":
                var params: [String: JSONValue?]?
                if case .object(let members)? = op["params"] {
                    params = members.mapValues(ParityFixtures.resolvingMarkers)
                }
                let found = FormValues.find(
                    op["field"]?.stringValue ?? "", params: params,
                    state: op["state"].flatMap(ParityFixtures.resolvingMarkers))
                #expect(found == expect, "op \(index)")
                #expect((found == nil) == (expect == nil), "op \(index)")
            case "flatten":
                #expect(JSONValue.object(state.flattenedToPointers()) == expect, "op \(index)")
            default:
                Issue.record("Unknown op \(kind)")
            }
        }
        #expect(state == fixture.value("expected"))
    }
}

/// A test-only RFC 6902 replayer built from the four path operations, with upstream
/// `applySpecStreamPatch` semantics. jr-2 owns the product implementation; this exists so
/// the state fixtures that use `patch` exercise the path operations here.
enum PatchReplayer {
    static func apply(_ patch: JSONValue, to state: inout JSONValue) throws(PatchTestFailure) {
        let path = patch["path"]?.stringValue ?? ""
        let from = patch["from"]?.stringValue
        let value = patch["value"].flatMap(ParityFixtures.resolvingMarkers)
        switch patch["op"]?.stringValue {
        case "add":
            if let pointer = try? JSONPointer(path), let value { state.add(value, at: pointer) }
        case "replace":
            if let pointer = try? JSONPointer(path), let value { state.set(value, at: pointer) }
        case "remove":
            if let pointer = try? JSONPointer(path) { state.remove(at: pointer) }
        case "move":
            guard let from, !from.isEmpty else { return }
            let moved = state.value(at: JSONPointer(lenient: from))
            if let source = try? JSONPointer(from) { state.remove(at: source) }
            if let pointer = try? JSONPointer(path), let moved { state.add(moved, at: pointer) }
        case "copy":
            guard let from, !from.isEmpty else { return }
            let copied = state.value(at: JSONPointer(lenient: from))
            if let pointer = try? JSONPointer(path), let copied { state.add(copied, at: pointer) }
        case "test":
            guard let value, state.test(value, at: JSONPointer(lenient: path)) else {
                throw PatchTestFailure(
                    message: "Test operation failed: value at \"\(path)\" does not match")
            }
        default:
            break
        }
    }
}

struct PatchTestFailure: Error, Equatable {
    let message: String
}
