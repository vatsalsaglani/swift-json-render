import Testing

@testable import JSONRenderCore

/// `upstream/validation/*.json`: `runValidation` and the `check.*` helpers.
@Suite("Validation parity (upstream/validation)")
struct ValidationParityTests {
    static let custom: [String: ValidationFunction] = [
        "startsWithA": { value, _ in value?.stringValue?.hasPrefix("A") ?? false }
    ]

    @Test("Replays the case", arguments: ParityFixtures.cases("validation"))
    func replay(_ fixture: FixtureCase) throws {
        switch fixture.kind {
        case "run": try run(fixture)
        case "helper": helper(fixture)
        default: Issue.record("Unknown kind \(fixture.kind ?? "nil")")
        }
    }

    private func run(_ fixture: FixtureCase) throws {
        let config = try ValidationConfig(json: fixture.value("config") ?? [:])
        var custom: [String: ValidationFunction] = [:]
        if case .array(let names)? = fixture.raw("customFunctions") {
            for case .string(let name) in names { custom[name] = Self.custom[name] }
        }
        let result = Validator.run(
            config, value: fixture.value("value"), state: fixture.value("state") ?? [:],
            custom: custom)
        let expected = fixture.raw("expected")
        #expect(result.valid == expected?["valid"]?.boolValue)
        #expect(.array(result.errors.map(JSONValue.string)) == expected?["errors"])
        if let count = expected?["checkCount"]?.numberValue {
            #expect(Double(result.checks.count) == count)
        }
        if case .array(let checks)? = expected?["checks"] {
            #expect(
                result.checks.map {
                    JSONValue.object([
                        "type": .string($0.type), "valid": .bool($0.valid),
                        "message": .string($0.message),
                    ])
                } == checks)
        }
    }

    private func helper(_ fixture: FixtureCase) {
        let args = fixture.raw("args")?.arrayValue ?? []
        let number = args.first?.numberValue ?? 0
        let text = args.first?.stringValue ?? ""
        let message = args.count > 1 ? args[1].stringValue : args.first?.stringValue
        let check: ValidationCheck? =
            switch fixture.raw("fn")?.stringValue {
            case "required": message.map(ValidationCheck.required) ?? .required()
            case "email": message.map(ValidationCheck.email) ?? .email()
            case "url": message.map(ValidationCheck.url) ?? .url()
            case "numeric": message.map(ValidationCheck.numeric) ?? .numeric()
            case "minLength": .minLength(number, args.count > 1 ? message : nil)
            case "maxLength": .maxLength(number, args.count > 1 ? message : nil)
            case "min": .min(number, args.count > 1 ? message : nil)
            case "max": .max(number, args.count > 1 ? message : nil)
            case "pattern": args.count > 1 ? .pattern(text, message ?? "") : .pattern(text)
            case "matches": args.count > 1 ? .matches(text, message ?? "") : .matches(text)
            case "equalTo": args.count > 1 ? .equalTo(text, message ?? "") : .equalTo(text)
            case "lessThan": .lessThan(text, args.count > 1 ? message : nil)
            case "greaterThan": .greaterThan(text, args.count > 1 ? message : nil)
            case "requiredIf": args.count > 1 ? .requiredIf(text, message ?? "") : .requiredIf(text)
            default: nil
            }
        guard let check, case .object(let expected)? = fixture.raw("expected") else {
            Issue.record("Unknown helper")
            return
        }
        let actual = check.jsonValue
        for (key, value) in expected {
            #expect(actual[key] == value, "\(key)")
        }
        if fixture.raw("partial") != .bool(true) {
            #expect(actual.objectValue?.count == expected.count)
        }
    }
}

@Suite("Built-in validation edges")
struct BuiltInValidationTests {
    @Test("numeric follows JavaScript Number()")
    func numeric() {
        let numeric = BuiltInValidation.functions["numeric"]!
        for text in ["1", " 2.5 ", "1e3", "0x1F", "-4", ".5", "Infinity"] {
            #expect(numeric(.string(text), [:]), "\(text)")
        }
        for text in ["", "  ", "12px", "1,000", "0x", "--1", "e5"] {
            #expect(!numeric(.string(text), [:]), "\(text)")
        }
    }

    @Test("Lengths count UTF-16 units, as JavaScript")
    func lengths() {
        let minLength = BuiltInValidation.functions["minLength"]!
        #expect(minLength(.string("😀"), ["min": 2]))
    }

    @Test("Fourteen names, fourteen prompt lines")
    func names() {
        #expect(BuiltInValidation.names.count == 14)
        #expect(Set(BuiltInValidation.functions.keys) == Set(BuiltInValidation.names))
        #expect(BuiltInValidation.promptLines.count == 14)
    }

    @Test("An unknown check passes and is flagged")
    func unknown() {
        let result = Validator.runCheck(
            ValidationCheck(type: "nope", message: "m"), value: nil, state: [:])
        #expect(result.valid && result.unknownFunction)
    }

    @Test("A built-in name wins over a custom function")
    func builtInWins() {
        let result = Validator.runCheck(
            .required(), value: nil, state: [:], custom: ["required": { _, _ in true }])
        #expect(!result.valid)
    }
}

@Suite("FormValidator")
struct FormValidatorTests {
    @Test("validateAll lists only failing fields")
    func validateAll() async {
        let validator = FormValidator()
        await validator.register(
            path: "/form/email", config: ValidationConfig(checks: [.email("Bad email")]))
        await validator.register(
            path: "/form/name", config: ValidationConfig(checks: [.required("Name")]))
        let outcome = await validator.validateAll(
            state: ["form": ["email": "x", "name": "Ada"]])
        #expect(!outcome.valid)
        #expect(outcome.errors == ["/form/email": ["Bad email"]])
        #expect(outcome.jsonValue == ["valid": false, "errors": ["/form/email": ["Bad email"]]])
    }

    @Test("enabled false skips the field")
    func enabled() async {
        let validator = FormValidator()
        await validator.register(
            path: "/a",
            config: ValidationConfig(
                checks: [.required()], enabled: VisibilityCondition(json: ["$state": "/on"])))
        #expect(await validator.validateAll(state: ["on": false]).valid)
        #expect(!(await validator.validateAll(state: ["on": true]).valid))
    }

    @Test("Unregister removes the field; custom validators run")
    func unregisterAndCustom() async {
        let validator = FormValidator(custom: ["isA": { value, _ in value == "A" }])
        await validator.register(
            path: "/x",
            config: ValidationConfig(checks: [ValidationCheck(type: "isA", message: "m")]))
        #expect(await validator.validate(path: "/x", state: ["x": "A"])?.valid == true)
        #expect(await validator.lastResult(path: "/x")?.valid == true)
        await validator.unregister(path: "/x")
        #expect(await validator.validate(path: "/x", state: [:]) == nil)
        #expect(await validator.registeredPaths.isEmpty)
    }

    @Test("validateForm writes the outcome through the dispatcher")
    func dispatcher() async throws {
        let store = StateStore(initial: ["email": "bad"])
        let validator = FormValidator()
        await validator.register(path: "/email", config: ValidationConfig(checks: [.email("Bad")]))
        let dispatcher = ActionDispatcher(
            catalog: Catalog(), store: store, host: NoopActionHost(), validation: validator)
        try await dispatcher.dispatch(
            ActionBinding(action: "validateForm"), elementID: nil,
            context: PropResolutionContext(state: [:]))
        #expect(
            await store.get("/formValidation") == ["valid": false, "errors": ["/email": ["Bad"]]])
    }
}
