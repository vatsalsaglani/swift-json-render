import Foundation
import Testing

@testable import JSONRenderCore

/// Deep JSON must not overflow a cooperative-pool thread (512 KiB stack). Every check runs
/// in `Task.detached`, so the stack matches production; results return to the test body.
@Suite("Depth limits")
struct DepthLimitTests {
    static func nestedArrays(_ depth: Int) -> String {
        String(repeating: "[", count: depth) + "0" + String(repeating: "]", count: depth)
    }

    /// A spec whose total container nesting is `depth` (the outer object, `elements`, the
    /// element and `props` are four levels).
    static func spec(depth: Int) -> Data {
        Data(
            (#"{"root":"a","elements":{"a":{"type":"T","props":{"v":"#
                + nestedArrays(depth - 4) + "}}}}").utf8)
    }

    @Test("JSONValue decodes 64 levels and refuses 65 and 300")
    func jsonValueDepth() async {
        let results = await Task.detached { () -> [Bool] in
            ([64, 65, 300] as [Int]).map { depth in
                (try? JSONDecoder().decode(
                    JSONValue.self, from: Data(Self.nestedArrays(depth).utf8))) != nil
            }
        }.value
        #expect(results == [true, false, false])
    }

    @Test("Spec.decode: 64 levels decode; 65 and 10,000 levels are invalid JSON")
    func specDepth() async {
        let outcomes = await Task.detached { () -> [String] in
            ([64, 65, 10_000] as [Int]).map { depth in
                do {
                    _ = try Spec.decode(Self.spec(depth: depth))
                    return "ok"
                } catch {
                    if case .invalidJSON? = error as? SpecDecodeError { return "invalidJSON" }
                    return "other"
                }
            }
        }.value
        #expect(outcomes == ["ok", "invalidJSON", "invalidJSON"])
    }

    @Test("The recursive operations are safe at the 64-level cap")
    func operationsAtCap() async throws {
        let ok = try await Task.detached { () -> Bool in
            let value = try JSONDecoder().decode(
                JSONValue.self, from: Data(Self.nestedArrays(64).utf8))
            var hasher = Hasher()
            value.hash(into: &hasher)
            _ = hasher.finalize()
            var resolver = PropResolver(context: PropResolutionContext(state: [:]))
            let resolved = resolver.resolveValue(value)
            let deep = BuiltInAction.deepResolve(value, state: [:])
            let condition = VisibilityCondition(json: value)
            return resolved == value && deep == value && condition.jsonValue == value
        }.value
        #expect(ok)
    }

    @Test("Writes refuse a pointer deeper than the cap; reads accept it")
    func writeTokenCap() async {
        let results = await Task.detached { () -> [Bool] in
            let deep = JSONPointer(tokens: Array(repeating: "a", count: 10_000))
            var state: JSONValue = [:]
            let set = state.set(1, at: deep)
            let add = state.add(1, at: deep)
            let remove = state.remove(at: deep)
            let read = state.value(at: deep) == nil
            let atCap = state.set(1, at: JSONPointer(tokens: Array(repeating: "a", count: 64)))
            let overCap = state.set(1, at: JSONPointer(tokens: Array(repeating: "b", count: 65)))
            return [set, add, remove, read, atCap, overCap]
        }.value
        #expect(results == [false, false, false, true, true, false])
    }

    @Test("The byte pre-scan ignores brackets inside strings")
    func prescanStrings() {
        let text = #"{"a":"[[[[\"{{{{","b":[1]}"#
        #expect(Spec.nestingExceeds(2, in: Data(text.utf8)) == nil)
        #expect(Spec.nestingExceeds(1, in: Data(text.utf8)) == 2)
    }
}
