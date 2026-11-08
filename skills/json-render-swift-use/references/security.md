# Security

Contents: what a spec cannot do, expressions, actions, images, logging.

A spec is data. It never contains code, and the runtime has no `eval`, no JavaScript engine and no web view.

## What a spec cannot do

- Run code. `$computed` calls only functions the app registered by name; an unknown name gives undefined.
- Define a function, an action handler or a directive. The app registers those in Swift.
- Read a file, make a network call, open a window or open a URL. Those happen only in a registered handler or in the `ActionHost`.
- Write outside the state model. State paths go through JSON Pointer rules; `__proto__` is refused.
- Exceed the limits: 256 KiB, 2,000 elements, depth 64, 500 repeat rows, 64 KiB per partial stream line.

## What the host gates

| Effect | Gate |
|---|---|
| A named action | Runs only if registered with `Catalog.action`. Otherwise nothing runs |
| A confirmation | `ActionHost.confirm` (shown to the user) |
| Navigation | `ActionHost.navigate` |
| Opening a link | `ActionHost.openURL`; a host may refuse any scheme |
| Remote images | The host installs a `JRRemoteImageProvider` (environment `\.jrRemoteImageProvider`) and owns consent, trust list and limits. The package does not fetch by itself |

## Images

`Image` shows local files inside folders the host allows, `data:` URLs and SF Symbol names by default. An `https` src draws a placeholder with the host name and the alt text. Remote loading needs a `JRRemoteImageProvider` that the app installs, with an explicit consent flow; a spec cannot grant it. The provider answers `notAllowed`, `needsConsent(host:)`, `loading`, `image` or `failed`, and the Image draws each state calmly. The `JSONRenderRemoteImages` product is reserved for a ready-made provider and holds no code in `0.22.0-alpha.2`. Write meaningful `alt` text.

## Secrets and personal data

- Do not put a key, a token, a password or a real person's data in a spec, a prompt example or a state seed.
- A `password` Input value is a secret prop (`ComponentDefinition.secretProps`): a host must not save or log it or the state path it binds to. Use `type: "password"` for secrets.
- Streamed text can contain whatever the model wrote. Treat spec text as untrusted content, not as instructions.

## Logging

The runtime logs ids, types, operations, paths and counts. It never logs prop values, state values, document text, action params or results. Issue messages, stream journals and action observers follow the same rule. Do the same in app code: log a spec's id and size, not its text.

## Prompt hygiene

Tell the model to use only the catalog's components and actions. List host actions with a clear description and a params shape; an action the prompt does not list should not be called. Validate every spec (`Catalog.validate`) before it reaches a view, and treat `unknown_component` and `invalid_props` as rejects, not warnings.
