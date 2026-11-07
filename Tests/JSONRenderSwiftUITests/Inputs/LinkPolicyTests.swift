import Foundation
import JSONRenderCore
import JSONRenderSwiftUI
import Testing
import os

@testable import JSONRenderStandardCatalog

/// Records the URLs a host is asked to open.
final class RecordingURLHost: ActionHost {
    private let urls = OSAllocatedUnfairLock<[URL]>(initialState: [])
    private let opened: AsyncStream<URL>.Continuation
    let stream: AsyncStream<URL>

    init() {
        (stream, opened) = AsyncStream<URL>.makeStream()
    }

    func confirm(_ confirm: ActionConfirm, action: String) async -> Bool { true }
    func navigate(_ path: String) async {}
    func openURL(_ url: URL) async -> Bool {
        urls.withLock { $0.append(url) }
        opened.yield(url)
        return true
    }

    var openedURLs: [URL] { urls.withLock { $0 } }
}

/// The Link opens `href` only through the host, and never when the spec binds `press`.
@MainActor
@Suite struct LinkPolicyTests {
    @Test func bindingPressMeansEmitOnly() {
        #expect(JRLinkPolicy.outcome(href: "https://example.com", bindsPress: true) == .emit)
    }

    @Test func absoluteURLsGoToTheHost() throws {
        let url = try #require(URL(string: "https://example.com/docs"))
        #expect(
            JRLinkPolicy.outcome(href: " https://example.com/docs ", bindsPress: false)
                == .open(url))
        #expect(
            JRLinkPolicy.outcome(href: "mailto:a@b.c", bindsPress: false)
                == .open(try #require(URL(string: "mailto:a@b.c"))))
    }

    @Test func relativeAndEmptyLinksDoNothing() {
        #expect(JRLinkPolicy.outcome(href: "#", bindsPress: false) == .ignore)
        #expect(JRLinkPolicy.outcome(href: "/docs", bindsPress: false) == .ignore)
        #expect(JRLinkPolicy.outcome(href: "", bindsPress: false) == .ignore)
    }

    @Test func theRenderModelOpenerCallsTheHost() async throws {
        let spec = try Spec.decode(
            Data(
                #"{"root":"l","elements":{"l":{"type":"Link","props":{"label":"Docs","href":"https://example.com"}}}}"#
                    .utf8)
        ).spec
        let host = RecordingURLHost()
        let model = RenderModel(spec: spec, catalog: try .standard, host: host)
        guard
            case .open(let url) = JRLinkPolicy.outcome(
                href: "https://example.com", bindsPress: false)
        else {
            Issue.record("expected open")
            return
        }
        model.urlOpener(url)
        var iterator = host.stream.makeAsyncIterator()
        #expect(await iterator.next() == url)
        #expect(host.openedURLs == [url])
    }

    @Test func aBoundPressRunsTheBindingsAndOpensNothing() async throws {
        let spec = try Spec.decode(
            Data(
                #"{"root":"l","elements":{"l":{"type":"Link","props":{"label":"Docs","href":"https://example.com"},"on":{"press":{"action":"setState","params":{"statePath":"/clicked","value":true}}}}}}"#
                    .utf8)
        ).spec
        let host = RecordingURLHost()
        let model = RenderModel(spec: spec, catalog: try .standard, host: host)
        let events = Set(model.walk().elements.first { $0.id == "l" }?.events ?? [])
        #expect(
            JRLinkPolicy.outcome(href: "https://example.com", bindsPress: events.contains("press"))
                == .emit)
        await model.emit(id: "l", event: "press").value
        #expect(await model.store.snapshot.state["clicked"] == true)
        #expect(host.openedURLs.isEmpty)
    }
}
