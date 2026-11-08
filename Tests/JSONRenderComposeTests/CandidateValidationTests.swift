import JSONRenderCompose
import JSONRenderCore
import Testing

@Suite("Candidate validation")
struct CandidateValidationTests {
    private let panel = CompositionCandidate(
        id: "panel", description: "A panel",
        element: UIElement(type: "Panel", props: ["title": "Settings"]))

    private func make(_ candidates: [CompositionCandidate]) throws(CompositionError) {
        _ = try Composer(
            catalog: MinimalCatalog.jev, candidates: candidates,
            evaluator: ScriptedEvaluator([:]))
    }

    private func reason(_ candidate: CompositionCandidate) -> CompositionError? {
        do {
            try make([panel, candidate])
            return nil
        } catch {
            return error
        }
    }

    private func child(
        _ id: String = "child", type: String = "Button",
        props: [String: JSONValue] = ["label": "Go"],
        on: [String: [ActionBinding]]? = nil
    ) -> CompositionCandidate {
        CompositionCandidate(
            id: id, description: "A child", element: UIElement(type: type, props: props, on: on),
            root: false)
    }

    @Test("The upstream jev candidates are accepted")
    func jevAccepted() throws {
        try make(try ComposeFixtures.candidates("jev-preferences"))
    }

    @Test("An unknown type is refused")
    func unknownType() {
        #expect(isInvalid(reason(child(type: "Carousel")), id: "child"))
    }

    @Test("A prop outside the schema is refused")
    func extraProp() {
        #expect(isInvalid(reason(child(props: ["label": "Go", "colour": "red"])), id: "child"))
    }

    @Test("A prop of the wrong type is refused")
    func wrongPropType() {
        #expect(isInvalid(reason(child(props: ["label": 4])), id: "child"))
    }

    @Test("An unknown action is refused")
    func unknownAction() {
        let candidate = child(on: ["press": [ActionBinding(action: "launchRockets")]])
        #expect(isInvalid(reason(candidate), id: "child"))
    }

    @Test("An unknown event is refused")
    func unknownEvent() {
        let candidate = child(on: ["hover": [ActionBinding(action: "setState")]])
        #expect(isInvalid(reason(candidate), id: "child"))
    }

    @Test("A built-in action is accepted")
    func builtInAction() {
        let candidate = child(
            on: ["press": [ActionBinding(action: "setState", params: ["statePath": "/x"])]])
        #expect(reason(candidate) == nil)
    }

    @Test("A navigate callback is refused, as upstream")
    func navigateCallback() {
        let candidate = child(
            on: [
                "press": [
                    ActionBinding(
                        action: "savePreferences", params: ["name": "x"], onSuccess: .navigate("/"))
                ]
            ])
        #expect(isInvalid(reason(candidate), id: "child"))
    }

    @Test(
        "Unsupported expressions are refused",
        arguments: [
            ["$computed": "now"] as JSONValue, ["$template": "Hi ${/name}"], ["$item": "name"],
            ["$state": 4],
        ])
    func unsupportedExpression(_ value: JSONValue) {
        #expect(isInvalid(reason(child(props: ["label": value])), id: "child"))
    }

    @Test("An action param with an unsupported expression is refused")
    func paramExpression() {
        let candidate = child(
            on: [
                "press": [
                    ActionBinding(
                        action: "savePreferences", params: ["name": ["$computed": "x"]])
                ]
            ])
        #expect(isInvalid(reason(candidate), id: "child"))
    }

    @Test("repeat and watch are refused")
    func repeatAndWatch() {
        var repeated = child()
        repeated.element.repeat = RepeatConfig(statePath: .absolute("/rows"))
        #expect(isInvalid(reason(repeated), id: "child"))
        var watched = child()
        watched.element.watch = ["/x": [ActionBinding(action: "setState")]]
        #expect(isInvalid(reason(watched), id: "child"))
    }

    @Test(
        "Duplicate, reserved and malformed ids are refused",
        arguments: ["panel", "node_0", "unavailable", "finish", "1st", "a b"])
    func badIDs(_ id: String) {
        #expect(isInvalid(reason(child(id)), id: id))
    }

    @Test("maxUses below one is refused")
    func maxUses() {
        var candidate = child()
        candidate.maxUses = 0
        #expect(isInvalid(reason(candidate), id: "child"))
    }

    @Test("No root-eligible candidate is refused")
    func noRoot() {
        var only = panel
        only.root = false
        #expect(throws: CompositionError.noRootCandidate) { try make([only]) }
    }

    @Test("Limits below one are refused")
    func badLimits() {
        #expect(throws: CompositionError.self) {
            _ = try Composer(
                catalog: MinimalCatalog.jev, candidates: [panel], evaluator: ScriptedEvaluator([:]),
                limits: ComposeLimits(maxElements: 0))
        }
        #expect(throws: CompositionError.self) {
            _ = try Composer(
                catalog: MinimalCatalog.jev, candidates: [panel], evaluator: ScriptedEvaluator([:]),
                limits: ComposeLimits(densityBudget: [4, 12]))
        }
    }

    @Test("Candidates decode with upstream defaults")
    func decodeDefaults() throws {
        let candidates = try ComposeFixtures.candidates("jev-preferences")
        #expect(candidates.map(\.root) == [true, false, false])
        #expect(candidates.allSatisfy { $0.maxUses == 1 && $0.resource == nil })
    }

    private func isInvalid(_ error: CompositionError?, id: String) -> Bool {
        if case .invalidCandidate(let failed, _)? = error { return failed == id }
        return false
    }
}
