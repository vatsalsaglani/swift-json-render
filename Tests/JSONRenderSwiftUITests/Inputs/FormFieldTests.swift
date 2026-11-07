import Foundation
import JSONRenderCore
import JSONRenderSwiftUI
import Testing

@testable import JSONRenderStandardCatalog

/// Form field wiring: which fields validate, when, and what they show.
@MainActor
@Suite struct FormFieldTests {
    private func spec(_ json: String) throws -> Spec { try Spec.decode(Data(json.utf8)).spec }

    private func context(bound: Bool) -> JRRenderContext {
        JRRenderContext(id: "f", bindings: bound ? ["value": "/form/email"] : [:])
    }

    private static let checks: [JSONValue] = [
        ["type": "required", "message": "Email is required"],
        ["type": "pattern", "args": ["pattern": "^[a-z]+@[a-z]+$"], "message": "Bad email"],
    ]

    @Test func onlyBoundFieldsWithChecksValidate() {
        #expect(
            FormFieldSpec(
                context: context(bound: false), valueProp: "value", checks: Self.checks,
                validateOn: nil, defaultOn: .blur) == nil)
        #expect(
            FormFieldSpec(
                context: context(bound: true), valueProp: "value", checks: [], validateOn: nil,
                defaultOn: .blur) == nil)
        let field = FormFieldSpec(
            context: context(bound: true), valueProp: "value",
            checks: Self.checks + [["type": 3]], validateOn: "bogus", defaultOn: .blur)
        #expect(field?.path == "/form/email")
        #expect(field?.validateOn == .blur)
        #expect(field?.config.checks?.count == 2)  // the malformed check is dropped
        let change = FormFieldSpec(
            context: context(bound: true), valueProp: "value", checks: Self.checks,
            validateOn: "change", defaultOn: .blur)
        #expect(change?.validateOn == .change)
    }

    @Test func messageIsTheFirstFailureAndNeutralForARefusedPattern() {
        #expect(JRFieldMessage(nil) == nil)
        #expect(JRFieldMessage(ValidationResult(valid: true, errors: [], checks: [])) == nil)
        let failed = ValidationResult(
            valid: false, errors: ["A", "B"],
            checks: [
                ValidationCheckResult(type: "required", valid: true, message: "x"),
                ValidationCheckResult(type: "minLength", valid: false, message: "A"),
                ValidationCheckResult(type: "email", valid: false, message: "B"),
            ])
        #expect(JRFieldMessage(failed) == JRFieldMessage(text: "A", kind: .error))
        let refused = ValidationResult(
            valid: false, errors: ["Spec text"],
            checks: [
                ValidationCheckResult(
                    type: "pattern", valid: false, message: "Spec text",
                    patternRefusal: .nestedQuantifier)
            ])
        let message = JRFieldMessage(refused)
        #expect(message?.text == "This pattern cannot be checked")
        #expect(message?.kind == .unchecked)
        #expect(message?.symbol != JRFieldMessage(failed)?.symbol)
    }

    private func model(email: String, validateOn: String) throws -> (RenderModel, FormFieldSpec) {
        let spec = try spec(
            #"{"root":"f","state":{"form":{"email":"\#(email)"}},"elements":{"f":{"type":"Input","props":{"label":"Email","name":"email","value":{"$bindState":"/form/email"}}}}}"#
        )
        let model = RenderModel(spec: spec, catalog: try .standard)
        let field = try #require(
            FormFieldSpec(
                context: context(bound: true), valueProp: "value", checks: Self.checks,
                validateOn: validateOn, defaultOn: .blur))
        return (model, field)
    }

    @Test func changeModeSkipsPatternChecksOnEachKeystroke() async throws {
        let (model, field) = try model(email: "NOT AN EMAIL", validateOn: "change")
        let validation = FormFieldValidation()
        validation.spec = field
        validation.model = model
        validation.changed()
        #expect(validation.message == nil)  // required passes; pattern does not run here
        model.write("/form/email", "")
        validation.changed()
        #expect(validation.message?.text == "Email is required")
        model.write("/form/email", "STILL BAD")
        validation.changed()
        #expect(validation.message == nil)
        // Blur runs every check, pattern included.
        await validation.blurred()
        #expect(validation.message?.text == "Bad email")
    }

    @Test func blurModeValidatesOnBlurOnly() async throws {
        let (model, field) = try model(email: "", validateOn: "blur")
        await model.formValidator.register(path: field.path, config: field.config)
        let validation = FormFieldValidation()
        validation.spec = field
        validation.model = model
        validation.changed()
        #expect(validation.message == nil)
        await validation.blurred()
        #expect(validation.message?.text == "Email is required")
        #expect(await model.formValidator.lastResult(path: field.path)?.valid == false)
    }

    @Test func submitModeWaitsForValidateFormAndThenShowsItsResult() async throws {
        let spec = try spec(
            #"""
            {"root":"f","state":{"form":{"email":""}},"elements":{
              "f":{"type":"Input","props":{"label":"Email","name":"email","value":{"$bindState":"/form/email"}}},
              "go":{"type":"Button","props":{"label":"Send"},"on":{"press":[{"action":"validateForm","params":{"statePath":"/result"}}]}}}}
            """#)
        let model = RenderModel(spec: spec, catalog: try .standard)
        let field = try #require(
            FormFieldSpec(
                context: context(bound: true), valueProp: "value", checks: Self.checks,
                validateOn: "submit", defaultOn: .blur))
        let validation = FormFieldValidation()
        validation.spec = field
        validation.model = model
        await model.formValidator.register(path: field.path, config: field.config)
        validation.changed()
        await validation.blurred()
        #expect(validation.message == nil)
        await model.emit(id: "go", event: "press").value
        let state = await model.store.snapshot.state
        #expect(state["result"]?["valid"] == false)
        #expect(state["result"]?["errors"]?["/form/email"] == ["Email is required", "Bad email"])
        await validation.refresh()
        #expect(validation.message?.text == "Email is required")
    }

    @Test func registerAndUnregisterDriveValidateForm() async throws {
        let (model, field) = try model(email: "", validateOn: "blur")
        let validator = model.formValidator
        await validator.register(path: field.path, config: field.config)
        #expect(await validator.registeredPaths == [field.path])
        #expect(await validator.validateAll(state: model.stateSnapshot.state).valid == false)
        await validator.unregister(path: field.path)
        #expect(await validator.registeredPaths.isEmpty)
        #expect(await validator.validateAll(state: model.stateSnapshot.state).valid)
    }

    @Test func refusedPatternShowsTheNeutralTextOnBlur() async throws {
        let spec = try spec(
            #"{"root":"f","state":{"v":"aaaa"},"elements":{"f":{"type":"Input","props":{"label":"V","name":"v"}}}}"#
        )
        let model = RenderModel(spec: spec, catalog: try .standard)
        let field = try #require(
            FormFieldSpec(
                context: JRRenderContext(id: "f", bindings: ["value": "/v"]), valueProp: "value",
                checks: [
                    ["type": "pattern", "args": ["pattern": "^(a+)+$"], "message": "Spec says no"]
                ], validateOn: "change", defaultOn: .blur))
        let validation = FormFieldValidation()
        validation.spec = field
        validation.model = model
        validation.changed()
        #expect(validation.message == nil)  // never on a keystroke
        await validation.blurred()
        #expect(
            validation.message
                == JRFieldMessage(text: JRFieldMessage.uncheckedText, kind: .unchecked))
    }
}

/// A bound Input publishes one store commit per keystroke.
@MainActor
@Suite struct BoundInputTests {
    @Test func tenKeystrokesAreTenCommits() async throws {
        let spec = try Spec.decode(
            Data(
                #"{"root":"f","state":{"form":{"name":""}},"elements":{"f":{"type":"Input","props":{"label":"Name","name":"name","value":{"$bindState":"/form/name"}}}}}"#
                    .utf8)
        ).spec
        let store = StateStore(initial: spec.state)
        let model = RenderModel(spec: spec, catalog: try .standard, store: store)
        let walk = model.walk()
        let input = try #require(walk.elements.first { $0.id == "f" })
        let pointer = try #require(input.bindings["value"])
        let context = JRRenderContext(id: "f", bindings: input.bindings)
        var typed = ""
        for character in "Ada Lovela" {
            typed.append(character)
            #expect(context.writeBound("value", .string(typed), with: model.bindingWriter))
        }
        await model.flushWrites()
        let snapshot = await store.snapshot
        #expect(snapshot.version == 10)
        #expect(snapshot.state.value(at: pointer) == "Ada Lovela")
    }
}
