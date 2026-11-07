// Owner: jr-2 (wave 2).
public import JSONRenderCore
public import SwiftUI

/// Renders a spec while it streams.
///
/// The view draws `content(snapshot, store)` and sets `\.jrStreamPhase` for it. The
/// snapshot changes at most once per display frame. The renderer inside `content` draws
/// skeletons for `snapshot.dangling` while the phase is `.streaming`.
///
/// Two forms:
/// - `init(stream:…)`: the view owns a `StreamModel` and starts the stream once, when it
///   first appears. If the view disappears mid-stream the stream stops (`.stopped`) and is
///   not restarted. Give the view a new `.id` to render a new stream.
/// - `init(model:…)`: the host owns the model and calls `model.run` itself (Rafu keeps the
///   model across view updates and cancels it from its own UI).
public struct JSONRenderStreamView<Content: View>: View {
    @State private var ownedModel: StreamModel?
    private let hostModel: StreamModel?
    private let start: Start?
    private let content: (SpecSnapshot, StateStore) -> Content

    private struct Start {
        let stream: AsyncThrowingStream<String, any Error>
        let mode: SpecStreamDecoder.Mode
        let onFinish: ((ValidationReport) -> Void)?
    }

    /// A view that owns its stream.
    public init(
        stream: AsyncThrowingStream<String, any Error>, mode: SpecStreamDecoder.Mode = .jsonl,
        catalog: Catalog, limits: SpecLimits = .default,
        onFinish: ((ValidationReport) -> Void)? = nil,
        @ViewBuilder content: @escaping (SpecSnapshot, StateStore) -> Content
    ) {
        hostModel = nil
        // SwiftUI keeps the first model and drops the ones later inits build (cheap: two
        // empty actors and an empty snapshot).
        _ownedModel = State(initialValue: StreamModel(catalog: catalog, limits: limits))
        start = Start(
            stream: stream, mode: mode, onFinish: onFinish)
        self.content = content
    }

    /// A view over a host-owned model.
    public init(
        model: StreamModel,
        @ViewBuilder content: @escaping (SpecSnapshot, StateStore) -> Content
    ) {
        hostModel = model
        start = nil
        self.content = content
    }

    public var body: some View {
        if let model = hostModel ?? ownedModel {
            content(model.snapshot, model.store)
                .environment(\.jrStreamPhase, model.phase)
                .task {
                    guard let start, model.phase == .idle else { return }
                    await model.run(start.stream, mode: start.mode, onFinish: start.onFinish)
                }
        }
    }
}
