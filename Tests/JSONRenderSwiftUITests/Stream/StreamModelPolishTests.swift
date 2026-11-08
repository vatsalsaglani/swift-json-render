import AppKit
import Foundation
import JSONRenderCore
import SwiftUI
import Testing

@testable import JSONRenderSwiftUI

/// jr-2p items 4, 6 and 7: a re-run resets the store, the generic and byte entry points, and
/// the default stream view content.
@MainActor
@Suite("StreamModel polish")
struct StreamModelPolishTests {
    static let transcript = [
        #"{"op":"add","path":"/root","value":"main"}"# + "\n",
        #"{"op":"add","path":"/elements/main","value":{"type":"Card","props":{"title":"héllo 日本"},"children":["t"]}}"#
            + "\n",
        #"{"op":"add","path":"/elements/t","value":{"type":"Text","props":{}}}"# + "\n",
        #"{"op":"add","path":"/state","value":{"n":1}}"# + "\n",
    ]

    static func model() -> StreamModel {
        StreamModel(catalog: Catalog(), clock: ManualFrameClock())
    }

    @Test("A re-run of an initial spec without state starts from an empty store")
    func rerunResetsTheStore() async {
        let model = Self.model()
        let (first, firstInput) = AsyncThrowingStream.makeStream(of: String.self)
        firstInput.yield(#"{"op":"add","path":"/state","value":{"count":3}}"# + "\n")
        firstInput.finish()
        await model.run(first, mode: .jsonl)
        #expect(await model.store.snapshot.state["count"] == 3)
        let (second, secondInput) = AsyncThrowingStream.makeStream(of: String.self)
        secondInput.yield(#"{"op":"add","path":"/root","value":"main"}"# + "\n")
        secondInput.finish()
        await model.run(second, mode: .jsonl)
        #expect(model.phase == .final)
        #expect(await model.store.snapshot.state["count"] == nil)
        #expect(await model.store.snapshot.state == [:])
    }

    @Test("A re-run of an initial spec with state starts from that state")
    func rerunRestoresInitialState() async throws {
        let initial = Spec(root: "", elements: [:], state: ["seed": 1])
        let model = StreamModel(catalog: Catalog(), initial: initial, clock: ManualFrameClock())
        let (first, firstInput) = AsyncThrowingStream.makeStream(of: String.self)
        firstInput.yield(#"{"op":"add","path":"/state/extra","value":2}"# + "\n")
        firstInput.finish()
        await model.run(first, mode: .jsonl)
        #expect(await model.store.snapshot.state == ["seed": 1, "extra": 2])
        let (second, secondInput) = AsyncThrowingStream.makeStream(of: String.self)
        secondInput.finish()
        await model.run(second, mode: .jsonl)
        #expect(await model.store.snapshot.state == ["seed": 1])
    }

    @Test("String chunks, a generic sequence and byte chunks give the same snapshot")
    func entryPointsAgree() async {
        let throwing = Self.model()
        let (text, input) = AsyncThrowingStream.makeStream(of: String.self)
        for line in Self.transcript { input.yield(line) }
        input.finish()
        await throwing.run(text, mode: .jsonl)

        let generic = Self.model()
        let (plain, plainInput) = AsyncStream.makeStream(of: String.self)
        for line in Self.transcript { plainInput.yield(line) }
        plainInput.finish()
        await generic.run(plain, mode: .jsonl)

        // Bytes cut at every 7th byte, so scalars split across chunks.
        let bytes = Array(Self.transcript.joined().utf8)
        let data = Self.model()
        let (chunks, chunkInput) = AsyncStream.makeStream(of: Data.self)
        for start in stride(from: 0, to: bytes.count, by: 7) {
            chunkInput.yield(Data(bytes[start..<min(start + 7, bytes.count)]))
        }
        chunkInput.finish()
        await data.run(bytes: chunks, mode: .jsonl)

        for model in [throwing, generic, data] {
            #expect(model.phase == .final)
            #expect(model.journal.isEmpty)
        }
        #expect(throwing.snapshot.spec == generic.snapshot.spec)
        #expect(throwing.snapshot.spec == data.snapshot.spec)
        #expect(throwing.snapshot.plan == data.snapshot.plan)
        #expect(data.snapshot.spec.elements["main"]?.props["title"] == "héllo 日本")
        #expect(await data.store.snapshot.state == ["n": 1])
    }

    @Test("The default content renders a host-owned model with JSONRenderView")
    func defaultContent() async throws {
        _ = NSApplication.shared
        let catalog = Catalog()
        let model = Self.model()
        let view: JSONRenderStreamView<JSONRenderView> = JSONRenderStreamView(
            model: model, catalog: catalog)
        let host = NSHostingView(rootView: view.frame(width: 300, height: 200))
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        host.layoutSubtreeIfNeeded()
        let (text, input) = AsyncThrowingStream.makeStream(of: String.self)
        for line in Self.transcript { input.yield(line) }
        input.finish()
        await model.run(text, mode: .jsonl)
        host.layoutSubtreeIfNeeded()
        #expect(model.phase == .final)
        #expect(model.snapshot.plan.order == ["main", "t"])
        // The owning form type-checks with the default content too.
        let (other, otherInput) = AsyncThrowingStream.makeStream(of: String.self)
        otherInput.finish()
        let owning: JSONRenderStreamView<JSONRenderView> = JSONRenderStreamView(
            stream: other, catalog: catalog)
        _ = NSHostingView(rootView: owning)
    }
}
