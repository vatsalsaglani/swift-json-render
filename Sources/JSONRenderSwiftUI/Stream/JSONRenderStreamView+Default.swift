// Owner: jr-2p (wave 4). The default content of a stream view: `JSONRenderView`.
public import JSONRenderCore
internal import SwiftUI

extension JSONRenderStreamView where Content == JSONRenderView {
    /// A view that owns its stream and renders each snapshot with `JSONRenderView`.
    ///
    /// ```swift
    /// JSONRenderStreamView(stream: chunks, catalog: try .standard)
    /// ```
    ///
    /// The same as `init(stream:mode:catalog:limits:onFinish:content:)` with
    /// `JSONRenderView(snapshot:catalog:store:host:observer:)` as the content. Actions that
    /// need the host (`navigate`, `openURL`, confirmations) go to `host`.
    public init(
        stream: AsyncThrowingStream<String, any Error>, mode: SpecStreamDecoder.Mode = .jsonl,
        catalog: Catalog, host: any ActionHost = NoopActionHost(),
        limits: SpecLimits = .default, observer: (any ActionObserver)? = nil,
        onFinish: ((ValidationReport) -> Void)? = nil
    ) {
        self.init(
            stream: stream, mode: mode, catalog: catalog, limits: limits, onFinish: onFinish
        ) { snapshot, store in
            JSONRenderView(
                snapshot: snapshot, catalog: catalog, store: store, host: host,
                observer: observer)
        }
    }

    /// A view over a host-owned model that renders each snapshot with `JSONRenderView`.
    public init(
        model: StreamModel, catalog: Catalog, host: any ActionHost = NoopActionHost(),
        observer: (any ActionObserver)? = nil
    ) {
        self.init(model: model) { snapshot, store in
            JSONRenderView(
                snapshot: snapshot, catalog: catalog, store: store, host: host,
                observer: observer)
        }
    }
}
