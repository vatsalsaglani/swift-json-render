# Security

A spec is data. The runtime has no way to run code from it.

## What a spec cannot do

- Run code. `$computed` calls only functions the app registered by name, and an unknown name gives undefined. There is no `eval`, no JavaScript engine and no web view.
- Define a function, an action handler or a directive. The app registers those in Swift.
- Read a file, make a network call, open a window or open a URL. Those happen only in a registered handler or in the `ActionHost`.
- Write outside the state model. State paths follow RFC 6901, and `__proto__` is refused everywhere.
- Exceed the limits: 256 KiB, 2,000 elements, depth 64, 500 repeat rows, and 64 KiB per partial stream line.

## What the host gates

| Effect | Gate |
|---|---|
| A named action | Runs only if registered with ``Catalog/action(_:params:description:handler:)`` |
| A confirmation | `ActionHost.confirm`, shown to the user |
| Navigation | `ActionHost.navigate` |
| Opening a link | `ActionHost.openURL`. A `Link` with `on.press` opens nothing; one without it hands an absolute URL to the host, which may refuse any scheme |
| A remote image | A `JRRemoteImageProvider` that the app installs. The package fetches nothing by itself |

## Networking has two homes

Only two targets may talk to a network, and a test enforces it. `JSONRenderCompose` calls the OpenAI Decisions API, and only when the app asks. `JSONRenderRemoteImages` is the home of a ready-made image provider; it is empty in this release. Every other target, including the core, the renderer and the charts, has no networking code. `NetworkBoundaryTests` reads the sources, and the CI `macos` job also checks the compiled objects.

The standard `Image` shows local files inside folders the host allows, `data:` URLs and SF Symbol names. An `https` source draws a placeholder until the app installs a provider, and the provider owns consent, the trust list and the fetch limits. A spec cannot grant consent.

## Secrets and personal data

- Never put a key, a token, a password or a real person's data in a spec, a prompt example, a fixture or a log.
- A `password` Input value is a secret prop. A component lists such props in `ComponentDefinition.secretProps`, and a host must not save or log them or the state paths they bind to.
- The composer reads its API key from a closure the app supplies, once per request. It puts the key only in that request's header and never stores, logs or prints it. It never sends props, bindings or state to the evaluator.
- Streamed text can hold anything the model wrote. Treat spec text as untrusted content, not as instructions.

## Logging

The runtime logs ids, types, operations, paths and counts. It never logs prop values, state values, document text, action params or results, request bodies or credentials. Validation messages, stream journals and action observers follow the same rule. Do the same in app code: log a spec's id and size, not its text.

## Hygiene for model output

List only the components and actions you want in the prompt. Validate every spec with `Catalog.validate` before it reaches a view, and treat `unknown_component` and `invalid_props` as rejects.
