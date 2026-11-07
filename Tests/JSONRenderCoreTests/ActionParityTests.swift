import Testing

@testable import JSONRenderCore

/// `upstream/actions/*.json`: `interpolateString`, `resolveAction`, `resolveActionParam` and
/// `executeAction`, replayed through `ActionBinding.resolved(in:)` and `ActionDispatcher`.
@Suite("Action parity (upstream/actions)")
struct ActionParityTests {
    @Test("Replays the case", arguments: ParityFixtures.cases("actions"))
    func replay(_ fixture: FixtureCase) async throws {
        switch fixture.kind {
        case "interpolate":
            for item in fixture.value("cases")?.arrayValue ?? [] {
                let result = ActionBinding.interpolate(
                    item["input"]?.stringValue ?? "", state: item["state"] ?? [:])
                #expect(.string(result) == item["expected"])
            }
        case "resolve":
            let binding = try ActionBinding(json: fixture.raw("binding") ?? .null)
            let (resolved, _) = binding.resolved(
                in: PropResolutionContext(state: fixture.value("state") ?? [:]))
            let expected = fixture.value("expectedResolved")
            #expect(.string(resolved.action) == expected?["action"])
            #expect(JSONValue.object(resolved.params.defined) == expected?["params"])
            #expect(resolved.confirm?.jsonValue == expected?["confirm"])
            #expect(resolved.onSuccess?.jsonValue == expected?["onSuccess"])
            #expect(resolved.onError?.jsonValue == expected?["onError"])
        case "param":
            var resolver = PropResolver(context: try ParityFixtures.context(fixture))
            let actual = fixture.value("input").flatMap { resolver.resolveActionParam($0) }
            #expect(actual == fixture.value("expected"))
        case "execute":
            try await execute(fixture)
        default:
            Issue.record("Unknown kind \(fixture.kind ?? "nil")")
        }
    }

    /// `executeAction` with a handler that resolves or rejects. `setState` calls are checked
    /// against the final store; `handler`, `navigate` and `executeAction` calls against the
    /// ordered call log (`executeAction` is observed as the follow-up action's handler).
    private func execute(_ fixture: FixtureCase) async throws {
        let binding = try ActionBinding(json: fixture.raw("action") ?? .null)
        let rejects =
            fixture.value("handler") == "resolves"
            ? nil : fixture.value("errorMessage")?.stringValue
        let log = CallLog()
        var catalog = Catalog()
        catalog.action(binding.action) { params, _ in
            await log.append("handler", [.object(params.defined)])
            if let rejects { throw ActionFailure(rejects) }
            return nil
        }
        for followUp in [binding.onSuccess?.jsonValue, binding.onError?.jsonValue] {
            guard case .string(let name)? = followUp?["action"] else { continue }
            catalog.action(name) { params, _ in
                var call: [String: JSONValue] = ["action": .string(name)]
                if !params.isEmpty { call["params"] = .object(params.defined) }
                await log.append("executeAction", [.object(call)])
                return nil
            }
        }
        let store = StateStore()
        let dispatcher = ActionDispatcher(
            catalog: catalog, store: store, host: RecordingHost(log: log))
        let context = PropResolutionContext(state: [:])
        if let message = fixture.value("expectThrows")?.stringValue {
            await #expect(throws: ActionFailure(message)) {
                try await dispatcher.dispatch(binding, elementID: nil, context: context)
            }
        } else {
            try await dispatcher.dispatch(binding, elementID: nil, context: context)
        }
        var expectedLog: [CallLog.Call] = []
        for call in fixture.value("expectedCalls")?.arrayValue ?? [] {
            let fn = call["fn"]?.stringValue ?? ""
            let args = call["args"]?.arrayValue ?? []
            if fn == "setState" {
                let path = JSONPointer(lenient: args.first?.stringValue ?? "")
                #expect(await store.get(path) == args.dropFirst().first, "setState \(path)")
            } else {
                expectedLog.append(CallLog.Call(fn: fn, args: args))
            }
        }
        #expect(await log.calls == expectedLog)
    }
}
