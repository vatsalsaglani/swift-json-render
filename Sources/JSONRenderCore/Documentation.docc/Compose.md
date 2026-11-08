# Compose

An optional target that picks, places and orders app-supplied elements with the OpenAI Decisions API.

## What it is

`JSONRenderCompose` is the batched form of upstream's experimental composer, with the OpenAI Decisions API in place of a model call. The app supplies candidates: element recipes with an id and a one-line description. The evaluator answers short questions about them, and the composer builds a spec only from those answers.

Nothing here is on by default. An app opts in by importing `JSONRenderCompose` and creating a `Composer` with a catalog, a candidate list and a `DecisionEvaluator`. `OpenAIDecisionsEvaluator` is the one that calls the network; every other evaluator, such as a recorded one in a test, makes no request.

## What the evaluator sees

The evaluator sees each candidate's `id` and `description`, the prompt, and the context the app chose to pass. It never sees props, bindings, state or the catalog. It cannot write prose or data, and it cannot run an action. The composer checks every candidate against the catalog before the first request, and refuses `$computed`, `$template`, directives, `repeat` and `watch`.

## How it runs

`Composer.compose(prompt:context:initialState:)` returns a stream of events. A `.step` carries a validated spec, so a half tree is never published, and `.complete` carries the final spec and why it stopped (`finish`, `limit` or `unavailable`).

1. A selection round asks for the root, which candidates to include, and how dense the layout should be.
2. A layout round asks for each parent and the order of its children.

That is two requests at most. The first preview is published after the first round. The stream is pull-based: a consumer that stops early causes no layout request, and cancelling the consuming task cancels the request in flight.

## Visible fallbacks

A refused question, or an answer below the confidence threshold, uses the catalog order. The step lists these in `refused` and `fallbacks`, so an app can say "arranged in default order". An evaluator failure does not throw: the composition ends `unavailable`.

## Safety

- The key comes from a closure, once per request, and goes only into that request's `Authorization` header. The evaluator never stores, logs or prints it, and errors and descriptions carry no body and no key.
- The base URL must be `https`. Otherwise the call fails with `DecisionError.insecureBaseURL` before the key is read.
- A candidate error is a `CompositionError`. (The core's `ComposeError` belongs to `Spec.composing`; see <doc:Nesting>.)
- Limits (`ComposeLimits`): 32 elements, depth 8, at most 400 questions per request.
