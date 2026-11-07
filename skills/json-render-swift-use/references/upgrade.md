# Upgrade

Contents: version policy, what a minor release may change, what never changes, upgrade steps, stored specs.

## Version policy

The package tracks the json-render spec by minor version: `0.22.x` follows upstream `@json-render/core` 0.22. Pre-release builds are tagged `0.22.0-alpha.N`. A patch release fixes bugs. The first minor with a new upstream spec feature raises the package minor. The parity fixtures pin one upstream commit; a new upstream minor means new fixtures and a new pin.

## A minor release may change

- New standard components, new optional props, new chart variants.
- The text of `Catalog.prompt()` (new rules, new component lines). Models see the change; specs written for the old prompt still validate.
- New validator rules and warnings. A new rule may flag a spec that was clean before.
- Theme defaults (token values), never the shape of a token struct inside a minor without a note in the changelog.
- New issue codes in `SpecIssue.Code` (the enum is not frozen; switch with a `default`).

## What never changes

- Spec semantics: the element shape, the expressions, visibility rules, repeat scope, state path rules, the action binding shape.
- Upstream names: component names, prop names, event names, built-in action names and their param names.
- Swift extensions that exist (`toggleState`, `incrementState`) keep their behaviour.
- The rule that customisation never changes semantics.
- The limits do not rise. A host may lower them.

## Upgrade steps

1. Read the release notes in `CHANGELOG.md` for the new version. <!-- verify at release: CHANGELOG.md is created by the coordinator -->
2. Change the version in `Package.swift`; resolve; build with warnings visible.
3. Regenerate the prompt (`catalog.prompt(...)`) and diff it against the stored one. Expected: new lines, not removed ones. A removed line is a breaking change; report it.
4. Re-run the validator on stored specs (below). Fix new errors; check new warnings.
5. Run the app's tests and open each screen that renders a spec.
6. If you wrote custom components, check that `@JRComponent` still produces the same definitions (compare `Metric.definition.props.formatted()`).

## Stored specs

Re-validate saved specs after any upgrade and before showing them:

```swift
import Foundation
import JSONRenderCore

func revalidate(_ stored: [String: Data], catalog: Catalog) -> [String: String] {
    var problems: [String: String] = [:]
    for (name, data) in stored.sorted(by: { $0.key < $1.key }) {
        do {
            let report = try catalog.validate(data: data)
            if !report.valid { problems[name] = report.formatted() }
        } catch {
            problems[name] = error.message
        }
    }
    return problems
}
```

`Catalog.validate(data:)` returns a `spec_too_large` issue for a document over 256 KiB and throws `SpecDecodeError` for invalid JSON or a wrong shape. Never print the spec text in the problem report; ids and codes are enough. Persisted view state (input values) is the app's: drop it when the spec changed.
