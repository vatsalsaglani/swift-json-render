# Install and quick start

Contents: add the package, products, platforms, render a spec, stream a spec, give a model the prompt, charts theme line, Linux, install the skills.

## Add the package

```swift
// Package.swift of your app or package
dependencies: [
    .package(url: "https://github.com/vatsalsaglani/swift-json-render.git", from: "0.22.0")
],
```

While the package is pre-release, pin an alpha tag: `exact: "0.22.0-alpha.0"`. In Xcode: File > Add Package Dependencies, use the same URL.

## Products

| Product | Use | Platforms |
|---|---|---|
| `JSONRenderCore` | Spec model, expressions, actions, state, validator, catalog, prompt, stream types. Foundation only | macOS, iOS, Linux |
| `JSONRenderClient` | `@JRComponent` and `@JRProp` macros for custom components | macOS, iOS, Linux |
| `JSONRenderSwiftUI` | `JSONRenderView`, `JSONRenderStreamView`, theme, style hooks, registry | macOS 14, iOS 17 |
| `JSONRenderStandardCatalog` | `Catalog.standard`: the 36 components, built-in actions, directives | macOS 14, iOS 17 |
| `JSONRenderCharts` | `Catalog.charts`: the 15 charts | macOS 14, iOS 17 |
| `JSONRenderRemoteImages` | Optional consented loading of `https` images | macOS 14, iOS 17 |
| `JSONRenderCompose` | Optional composer on a Decisions API | macOS, iOS, Linux |

The package needs Swift 6.2 tools. Add only what you use; an app that renders standard components needs `JSONRenderCore`, `JSONRenderSwiftUI` and `JSONRenderStandardCatalog`.

## Render a spec

```swift
// verify after jr-3 merges: JSONRenderView
import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI
import SwiftUI

struct SpecScreen: View {
    let spec: Spec
    let catalog: Catalog

    var body: some View {
        JSONRenderView(spec: spec, catalog: catalog)
    }
}
```

Build the `Spec` with `Spec.decode(data)` and the catalog with `try Catalog.standard`. Validate before you render (`spec.md`). Pass `host:` an `ActionHost` for confirmations, navigation and links (`actions.md`); the default `NoopActionHost` confirms everything and opens nothing. Pass `state:` a `StateStore` when the app needs to read or write state.

Merged catalogs: `try Catalog.standard.merging(Catalog.charts)`, then register your own components and actions.

## Stream a spec

```swift
// verify after jr-2 merges: JSONRenderStreamView
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI

struct Assistant: View {
    let lines: AsyncThrowingStream<String, any Error>
    let catalog: Catalog

    var body: some View {
        JSONRenderStreamView(stream: lines, mode: .jsonl, catalog: catalog)
    }
}
```

`mode` is `.jsonl` for patch lines, `.mixed` for chat text with a `spec` fence, `.object` for one JSON document in fragments. See `streaming.md`.

## Give a model the catalog

```swift
import JSONRenderCore
import JSONRenderStandardCatalog

func systemPrompt() throws -> String {
    let catalog = try Catalog.standard
    let options = PromptOptions(
        mode: .inline, customRules: ["Use one Card per topic."], includeExtensions: true)
    return catalog.prompt(options)
}
```

- `.standalone` (default) asks for JSONL only. `.inline` asks for prose, then JSONL in a `spec` fence.
- `includeExtensions: false` removes `toggleState` and `incrementState` for a spec that must also run on the web.
- `customRules` are appended to the rules. Put domain rules there, not in the user message.
- `editModes: [.patch]` adds editing instructions; `UserPrompt.build` builds the matching user message.
- `Catalog.jsonSchema(strict:)` gives a JSON Schema for tool arguments, but a strict schema treats `elements` as opaque and a model cannot fill it. For function-calling use the prompt with object mode instead.

A catalog without views (for a server or Linux) is just definitions:

```swift
import JSONRenderCore

func noteCatalog() throws -> Catalog {
    var catalog = Catalog()
    try catalog.register(
        ComponentDefinition(
            name: "Note", description: "A short note.",
            props: .object([.init(name: "text", schema: .string)]), slots: [], events: []))
    return catalog
}
```

## Charts theme line

`JSONRenderTheme.native` already carries a chart palette (`ChartTokens.standard`), so charts draw with no setup. If the charts product ships tuned tokens, set them once at the root:

```swift
// verify after jr-3 and jr-3c merge: ChartTokens.native, .jsonRenderTheme(_:_:)
content.jsonRenderTheme(\.charts, .native)
```

## Linux

Only the platform-neutral products build on Linux: `JSONRenderCore`, `JSONRenderClient`, `JSONRenderCompose` (and the macro target). Use them to decode, validate, repair and prompt on a server. `Catalog.standard` is in the Apple-only product, so a server builds its catalog from `ComponentDefinition`s or shares the app's definitions.

## Install these skills

```sh
npx skills add vatsalsaglani/swift-json-render --skill json-render-swift-use
npx skills add vatsalsaglani/swift-json-render --skill json-render-swift-update
```

The CLI copies the skill into the agent's skills folder (`.claude/skills/<name>/` for Claude Code). A future release may also ship the use skill as a package resource, so a tool description can read it at run time. <!-- verify at release: needs a resources entry in Package.swift -->
