# ``JSONRenderCore``

A native Swift runtime for the json-render specification. A model writes a small JSON tree, and SwiftUI draws it as native views.

## Overview

json-render defines a flat, streamable JSON grammar: a root id, elements by id, and state. swift-json-render reads that grammar and builds SwiftUI. There is no web view and no code evaluation: a spec is data, and every effect goes through a name that the app registered.

The package is spectacularly simple by default and highly customisable in layers. A card looks finished with no configuration. When you need more, you go one layer down, and customisation never changes what a spec means.

`JSONRenderCore` is the part with no UI. It holds the spec model, the expressions, the state store, the action dispatcher, the validator, the catalog and prompt, and the stream decoder. It uses Foundation only and builds on Linux. The articles in this catalog describe the whole package, because one `import JSONRender` brings the renderer and the standard catalog on Apple platforms.

This release is `0.22.0-alpha.2`. It implements json-render 0.22.0 (commit `1819412`).

## Topics

### Start here

- <doc:GettingStarted>

### The spec and its expressions

- <doc:SpecFormat>
- <doc:Expressions>
- <doc:Nesting>

### Streaming

- <doc:Streaming>

### Looks and charts

- <doc:Theming>
- <doc:Charts>

### Trust

- <doc:Security>
- <doc:Parity>

### Optional composer

- <doc:Compose>

### Core types

- ``Spec``
- ``SpecLimits``
- ``Catalog``
- ``StateStore``
- ``SpecStreamDecoder``
- ``SpecStore``
- ``PromptOptions``
