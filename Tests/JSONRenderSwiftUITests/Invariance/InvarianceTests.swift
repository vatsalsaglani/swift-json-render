import AppKit
import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI
import SwiftUI
import Testing

/// Layers a–f never change semantics: the same spec and the same interactions give the same
/// state transitions, the same dispatches and the same render contexts with the standard
/// views under `.native`, under `.highContrast`, and with every standard type replaced by
/// a stub view.
///
/// The model takes no theme input, so (a) and (b) differ only in the view environment; the
/// view-path check below renders both presets and compares the contexts the factories get.
@MainActor
@Suite struct InvarianceTests {
    /// What one run observed.
    struct Record: Equatable {
        var changes: [Set<JSONPointer>] = []
        var dispatches: [String] = []
        var contexts: [RenderWalk.Element] = []
    }

    enum Variant: CaseIterable { case native, highContrast, stubbed }

    static func catalog(_ variant: Variant) throws -> Catalog {
        var catalog = try Scripts.catalog()
        guard variant == .stubbed else { return catalog }
        for name in catalog.componentNames {
            try catalog.override(name) { _ in AnyView(EmptyView()) }
        }
        return catalog
    }

    func run(_ fixture: String, _ variant: Variant) async throws -> Record {
        let spec = try Fixtures.spec(fixture)
        let observer = RecordingObserver()
        let store = StateStore(initial: spec.state)
        let catalog = try Self.catalog(variant)
        let model = RenderModel(spec: spec, catalog: catalog, store: store, observer: observer)
        let subscription = await store.subscribe(bufferingPolicy: .unbounded)
        let watchers = await model.startWatchers()
        defer { watchers.cancel() }
        var record = Record()
        record.contexts = model.walk().elements
        for step in Scripts.steps(for: fixture, catalog: catalog) {
            switch step {
            case .write(let pointer, let value):
                model.write(pointer, value)
                await model.flushWrites()
            case .emit(let id, let event):
                await model.emit(id: id, event: event).value
            case .waitFor(let pointer, let value):
                await waitForState(store, pointer, equals: value)
            }
        }
        let finalVersion = await store.snapshot.version
        if finalVersion > subscription.current.version {
            for await snapshot in subscription.updates {
                record.changes.append(snapshot.changed)
                if snapshot.version >= finalVersion { break }
            }
        }
        record.dispatches = observer.entries
        return record
    }

    @Test(arguments: Fixtures.specNames)
    func sameTransitionsAndDispatchesInEveryVariant(_ fixture: String) async throws {
        let native = try await run(fixture, .native)
        let highContrast = try await run(fixture, .highContrast)
        let stubbed = try await run(fixture, .stubbed)
        #expect(native == highContrast)
        #expect(native == stubbed)
        // confetti has a Button root (group 2) and an action with no handler: nothing to
        // draw yet and nothing to commit.
        if fixture != "confetti" {
            #expect(!native.changes.isEmpty)
            #expect(!native.contexts.isEmpty)
        }
    }

    @Test func scriptsExerciseActionsAndWatchers() async throws {
        let registration = try await run("registration-form", .native)
        #expect(registration.dispatches.filter { $0.hasSuffix(":validateForm") }.count == 2)
        guard try Scripts.catalog().component(named: "Select") != nil else { return }
        let cascading = try await run("cascading-selects", .native)
        #expect(cascading.dispatches.filter { $0 == "countrySelect:setState" }.count == 4)
        #expect(cascading.changes.contains(["/availableCities"]))
    }

    /// Renders every fixture through real views with a recording factory per type, in both
    /// presets, and checks that the factories receive exactly the walk's contexts.
    @Test(arguments: Fixtures.specNames)
    func viewFactoriesReceiveTheWalkContexts(_ fixture: String) throws {
        _ = NSApplication.shared
        let spec = try Fixtures.spec(fixture)
        for theme in [JSONRenderTheme.native, .highContrast] {
            let recorder = ContextRecorder()
            var catalog = try Scripts.catalog()
            for name in catalog.componentNames {
                try catalog.override(name) { [recorder] context in
                    recorder.contexts.append(
                        RecordedContext(
                            id: context.id, props: context.props, bindings: context.bindings,
                            scope: context.scope))
                    return AnyView(StubView(context: context))
                }
            }
            let model = RenderModel(spec: spec, catalog: catalog)
            let host = NSHostingView(
                rootView: JSONRenderView(model: model).jsonRenderTheme(theme).frame(width: 600))
            host.frame = NSRect(x: 0, y: 0, width: 600, height: 2000)
            host.layoutSubtreeIfNeeded()
            let expected = model.walk().elements.map {
                RecordedContext(id: $0.id, props: $0.props, bindings: $0.bindings, scope: $0.scope)
            }
            #expect(Set(recorder.contexts) == Set(expected))
            #expect(Set(recorder.contexts.map(\.id)) == Set(expected.map(\.id)))
        }
    }
}

struct RecordedContext: Hashable {
    let id: String
    let props: [String: JSONValue?]
    let bindings: [String: JSONPointer]
    let scope: RepeatScope?
}

@MainActor
final class ContextRecorder {
    var contexts: [RecordedContext] = []
}

/// Draws a stub's children and slots so the walk continues below it.
private struct StubView: View {
    let context: JRRenderContext

    var body: some View {
        VStack {
            context.children
            ForEach(context.slots.keys.sorted(), id: \.self) { name in
                context.slots[name] ?? .empty
            }
        }
    }
}
