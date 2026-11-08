// Owner: jr-3b (wave 2). Form validation wiring for the standard input components.
internal import Foundation
public import JSONRenderCore
public import JSONRenderSwiftUI
internal import Observation
public import SwiftUI

/// The message under a form field.
public struct JRFieldMessage: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        /// A failed check: the spec's message.
        case error
        /// A `pattern` check that the ReDoS guard refused. The text is neutral.
        case unchecked
    }

    public let text: String
    public let kind: Kind

    /// The neutral text for a refused `pattern` check.
    public static let uncheckedText = "This pattern cannot be checked"

    /// The message for a result: the first failing check, or `nil` when it is valid.
    public init?(_ result: ValidationResult?) {
        guard let result, !result.valid,
            let failed = result.checks.first(where: { !$0.valid })
        else { return nil }
        if failed.patternRefused {
            self.init(text: JRFieldMessage.uncheckedText, kind: .unchecked)
        } else {
            self.init(text: failed.message, kind: .error)
        }
    }

    public init(text: String, kind: Kind) {
        self.text = text
        self.kind = kind
    }

    /// The SF Symbol drawn before the text (never colour alone).
    public var symbol: String {
        kind == .error ? "exclamationmark.circle.fill" : "questionmark.circle"
    }
}

/// The validation of one field: the state path its value binds and its configuration.
///
/// As upstream, a field validates only when its value prop is bound (`$bindState` or
/// `$bindItem`) and it has at least one check.
struct FormFieldSpec: Equatable {
    let path: JSONPointer
    let config: ValidationConfig
    let validateOn: ValidateOn

    /// Reads `checks` and `validateOn` from the element. `nil` when the field does not
    /// validate. A check that is not `{ type, message, args? }` is dropped.
    init?(
        context: JRRenderContext, valueProp: String, checks: [JSONValue]?,
        validateOn raw: String?, defaultOn: ValidateOn
    ) {
        guard let path = context.bindings[valueProp] else { return nil }
        let parsed = (checks ?? []).compactMap { try? ValidationCheck(json: $0) }
        guard !parsed.isEmpty else { return nil }
        let mode = raw.flatMap(ValidateOn.init(rawValue:)) ?? defaultOn
        self.path = path
        self.validateOn = mode
        self.config = ValidationConfig(checks: parsed, validateOn: mode)
    }
}

/// Runs the checks of one field and holds the message it shows.
///
/// - change: the checks run after each change, except `pattern` checks (an overlapping
///   pattern can be exponential, so `pattern` runs on blur or submit only).
/// - blur: every check runs through the `FormValidator` when the field loses focus.
/// - submit: the field validates only through `validateForm`.
///
/// After `validateForm`, the field shows the validator's result for its path.
@MainActor
@Observable
final class FormFieldValidation {
    private(set) var message: JRFieldMessage?

    @ObservationIgnored var spec: FormFieldSpec?
    @ObservationIgnored weak var model: RenderModel?
    @ObservationIgnored private var lastSeen: ValidationResult?

    init() {}

    /// Called after the value changed (the new value is already written).
    func changed() {
        guard let spec, spec.validateOn == .change, let model else { return }
        var config = spec.config
        config.checks = config.checks?.filter { $0.type != "pattern" }
        let state = model.stateSnapshot.state
        let result = Validator.run(
            config, value: state.value(at: spec.path), state: state,
            custom: model.catalog.validationFunctions)
        message = JRFieldMessage(result)
    }

    /// Called when the field loses focus. Runs every check (`pattern` included).
    func blurred() async {
        guard let spec, spec.validateOn != .submit, let model else { return }
        let state = model.stateSnapshot.state
        if let result = await model.formValidator.validate(path: spec.path, state: state) {
            lastSeen = result
            message = JRFieldMessage(result)
        } else {
            // Not registered yet (or no longer): run the same checks locally.
            message = JRFieldMessage(
                Validator.run(
                    spec.config, value: state.value(at: spec.path), state: state,
                    custom: model.catalog.validationFunctions))
        }
    }

    /// Takes the validator's last result when it changed without this field (for example
    /// after `validateForm`).
    func refresh() async {
        guard let spec, let model else { return }
        let result = await model.formValidator.lastResult(path: spec.path)
        guard result != lastSeen else { return }
        lastSeen = result
        message = JRFieldMessage(result)
    }
}

extension View {
    /// Registers the field in the render model's `FormValidator` while it is on screen and
    /// keeps its message current. Does nothing for a field without validation.
    func jrFormField(_ validation: FormFieldValidation, spec: FormFieldSpec?) -> some View {
        modifier(FormFieldModifier(validation: validation, spec: spec))
    }
}

private struct FormFieldModifier: ViewModifier {
    let validation: FormFieldValidation
    let spec: FormFieldSpec?
    @Environment(\.jrRenderModel) private var model

    func body(content: Content) -> some View {
        let _ = configure()
        content
            .task(id: spec?.path) {
                guard let spec, let validator = model?.formValidator else { return }
                await validator.register(path: spec.path, config: spec.config)
                await parkUntilCancelled()
                await validator.unregister(path: spec.path)
            }
            .onChange(of: spec?.config) { _, config in
                guard let spec, let config, let validator = model?.formValidator else { return }
                Task { await validator.register(path: spec.path, config: config) }
            }
            .onChange(of: model?.stateSnapshot.version) {
                guard spec != nil else { return }
                Task { await validation.refresh() }
            }
    }

    /// Hands the current spec and model to the validation object (no publish).
    private func configure() {
        validation.spec = spec
        validation.model = model
    }
}

/// Suspends until the task is cancelled (the view left the screen).
private func parkUntilCancelled() async {
    let (stream, continuation) = AsyncStream<Never>.makeStream()
    for await _ in stream {}
    continuation.finish()
}

/// The message under a field: a symbol and the text. VoiceOver reads it right after the
/// field as "Error, <text>" (or "Not checked, <text>"). It does not replace the field's
/// value, so the typed text stays readable.
public struct JRFieldMessageView: View {
    let message: JRFieldMessage
    let theme: JSONRenderTheme

    public init(message: JRFieldMessage, theme: JSONRenderTheme) {
        self.message = message
        self.theme = theme
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: message.symbol)
                .foregroundStyle(
                    message.kind == .error ? theme.color.critical : theme.color.textSecondary)
            Text(message.text)
                .foregroundStyle(
                    message.kind == .error ? theme.color.text : theme.color.textSecondary
                )
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(theme.type.footnote)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text("\(message.kind == .error ? "Error" : "Not checked"), \(message.text)"))
    }
}

/// The label above a field, the field, then its message: the shared default layout of
/// Input, Textarea, Select and Radio.
struct StandardFieldLayout: View {
    let label: String
    let control: JRStyleContent
    let message: JRFieldMessage?
    let theme: JSONRenderTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(theme.type.footnote.weight(theme.type.weights.medium))
                    .foregroundStyle(theme.color.textSecondary)
                    .accessibilityHidden(true)
            }
            control
            if let message { JRFieldMessageView(message: message, theme: theme) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
