// Owner: jr-3 (wave 2). Runs one element's `watch` bindings while the element is on screen.
internal import JSONRenderCore
internal import SwiftUI

/// Runs `WatchRunner` in a `.task` keyed by the element id, its row path and its watch
/// map. The baseline is the state when the task subscribes; the task ends with the view.
/// Attached only to elements that have a `watch` field.
struct WatchHost: ViewModifier {
    let id: String
    let watch: [String: [ActionBinding]]
    let scope: RepeatScope?
    let model: RenderModel

    private struct Key: Hashable {
        let id: String
        let basePath: JSONPointer?
        let watch: [String: [ActionBinding]]
    }

    func body(content: Content) -> some View {
        content.task(id: Key(id: id, basePath: scope?.basePath, watch: watch)) {
            let runner = WatchRunner(store: model.store, dispatcher: model.dispatcher)
            let functions = model.catalog.functions
            let directives = model.catalog.directives
            let subscription = await model.store.subscribe()
            await runner.run(
                elementID: id, watch: watch, subscription: subscription
            ) { [scope] snapshot in
                PropResolutionContext(
                    state: snapshot.state, scope: scope, functions: functions,
                    directives: directives)
            }
        }
    }
}
