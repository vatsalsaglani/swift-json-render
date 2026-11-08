import Foundation
import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI
import Testing

/// jr-2p item 9: `watch` runs on hidden elements and on unknown types (upstream parity).
@MainActor
@Suite struct HiddenWatchTests {
    /// `h` is hidden (`/show` is false) and `u` has a type no catalog knows. Both copy
    /// `/country` somewhere when it changes.
    static let json = #"""
        {"root":"s","state":{"show":false,"country":"","hiddenCopy":"","unknownCopy":""},
         "elements":{
          "s":{"type":"Stack","children":["h","u"]},
          "h":{"type":"Text","props":{"text":"hidden"},"visible":{"$state":"/show"},
               "watch":{"/country":{"action":"setState","params":{"statePath":"/hiddenCopy","value":{"$state":"/country"}}}}},
          "u":{"type":"NoSuchType","props":{},
               "watch":{"/country":{"action":"setState","params":{"statePath":"/unknownCopy","value":{"$state":"/country"}}}}}}}
        """#

    static func spec() throws -> Spec {
        try Spec.decode(Data(json.utf8)).spec
    }

    @Test func walkListsHiddenAndUnknownWatchSites() throws {
        let model = RenderModel(spec: try Self.spec(), catalog: try .standard)
        let walk = model.walk()
        #expect(walk.watchSites.map(\.id) == ["h", "u"])
        // The drawn-element list is unchanged: neither is drawn.
        #expect(walk.elements.map(\.id) == ["s"])
    }

    @Test func headlessWatchersFireForHiddenAndUnknownElements() async throws {
        let spec = try Self.spec()
        let observer = RecordingObserver()
        let store = StateStore(initial: spec.state)
        let model = RenderModel(
            spec: spec, catalog: try .standard, store: store, observer: observer)
        let watchers = await model.startWatchers()
        defer { watchers.cancel() }
        await store.set("/country", "UK")
        await waitForState(store, "/hiddenCopy", equals: "UK")
        await waitForState(store, "/unknownCopy", equals: "UK")
        #expect(
            Set(observer.entries.filter { $0.hasSuffix(":setState") })
                == ["h:setState", "u:setState"])
    }
}
