# Getting started

Add the package, render a spec, and stream one.

## Install

Add the package to your app or package. While it is pre-release, pin an exact alpha tag.

```swift
// Package.swift
.package(url: "https://github.com/vatsalsaglani/swift-json-render.git", exact: "0.22.0-alpha.2"),
```

An app that draws standard components needs one product, `JSONRender`. Add the others only when you use them.

| Product | What it holds | Platforms |
|---|---|---|
| `JSONRender` | One import: the core, the SwiftUI renderer and the standard catalog | macOS 14, iOS 17 |
| `JSONRenderCore` | Spec model, expressions, state, actions, validator, catalog, prompt, stream decoder | macOS, iOS, Linux |
| `JSONRenderSwiftUI` | `JSONRenderView`, `JSONRenderStreamView`, themes, style hooks | macOS 14, iOS 17 |
| `JSONRenderStandardCatalog` | `Catalog.standard`: 36 components, directives, built-in actions | macOS 14, iOS 17 |
| `JSONRenderCharts` | `Catalog.charts`: 15 charts | macOS 14, iOS 17 |
| `JSONRenderClient` | The `@JRComponent` macro for your own components | macOS, iOS, Linux |
| `JSONRenderCompose` | Optional batched composer on the OpenAI Decisions API | macOS, iOS, Linux |
| `JSONRenderRemoteImages` | Reserved for a ready-made `https` image provider; empty in this release | macOS 14, iOS 17 |

## Render a spec

```swift
import JSONRender
import SwiftUI

let json = """
{"root": "card", "elements": {
  "card": {"type": "Card", "props": {"title": "Hello"}, "children": ["text"]},
  "text": {"type": "Text", "props": {"text": "A native card from JSON."}, "children": []}}}
"""

struct HelloView: View {
    var body: some View {
        if let spec = try? Spec.decode(Data(json.utf8)).spec, let catalog = try? Catalog.standard {
            JSONRenderView(spec: spec, catalog: catalog)
        }
    }
}
```

`Spec.decode` reads the document. `Catalog.standard` is the standard catalog. Validate a spec before you draw it (see <doc:SpecFormat>).

## Stream a spec

```swift
import JSONRender
import SwiftUI

struct Assistant: View {
    let chunks: AsyncThrowingStream<String, any Error>

    var body: some View {
        if let catalog = try? Catalog.standard {
            JSONRenderStreamView(stream: chunks, mode: .jsonl, catalog: catalog)
        }
    }
}
```

The view draws at most once per display frame, shows skeletons for children that have not arrived, and keeps the last good picture when the stream stops. See <doc:Streaming>.

## Look around

The Gallery is a small app with a page for every component, every chart, the theme layers and a streaming replay. Run it from a checkout:

```sh
swift run --package-path Examples/Gallery Gallery
```

## Skills for coding agents

Two skills ship in the repository: one teaches an agent to write specs and wire the package into an app, and one teaches it to extend the package.

```sh
npx skills add vatsalsaglani/swift-json-render --skill json-render-swift-use
npx skills add vatsalsaglani/swift-json-render --skill json-render-swift-update
```
