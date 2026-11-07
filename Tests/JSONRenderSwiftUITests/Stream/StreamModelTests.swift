import JSONRenderCore
import Testing

@testable import JSONRenderSwiftUI

@MainActor
@Suite("StreamModel")
struct StreamModelTests {
    static let root = #"{"op":"add","path":"/root","value":"main"}"# + "\n"
    static let main =
        #"{"op":"add","path":"/elements/main","value":{"type":"Card","props":{},"children":["t"]}}"#
        + "\n"
    static let text =
        #"{"op":"add","path":"/elements/t","value":{"type":"Text","props":{}}}"# + "\n"

    static func model() -> StreamModel {
        StreamModel(catalog: Catalog(), clock: ManualFrameClock())
    }

    @Test("idle → streaming → final; onFinish once with the report")
    func phases() async {
        let model = Self.model()
        #expect(model.phase == .idle)
        let (text, input) = AsyncThrowingStream.makeStream(of: String.self)
        let finished = Recorder<ValidationReport>()
        let run = Task { await model.run(text, mode: .jsonl) { finished.values.append($0) } }
        _ = await observe({ model.phase }, until: { $0 == .streaming })
        input.yield(Self.root + Self.main)
        let streaming = await observe({ model.snapshot }, until: { $0.plan.rootID == "main" })
        #expect(streaming.dangling == ["t"])
        #expect(!streaming.isFinal)
        input.yield(Self.text)
        input.finish()
        await run.value
        #expect(model.phase == .final)
        #expect(finished.values.count == 1)
        #expect(model.report == finished.values.first)
        #expect(model.snapshot.isFinal)
        #expect(model.snapshot.dangling.isEmpty)
        #expect(model.snapshot.plan.order == ["main", "t"])
        #expect(model.frameStats.published >= 1)
    }

    @Test("cancel mid-stream: stopped, snapshot kept, no publish after")
    func cancelMidStream() async {
        let model = Self.model()
        let (text, input) = AsyncThrowingStream.makeStream(of: String.self)
        let run = Task { await model.run(text, mode: .jsonl) }
        input.yield(Self.root + Self.main)
        _ = await observe({ model.snapshot }, until: { $0.plan.rootID == "main" })
        model.cancel()
        await run.value
        #expect(model.phase == .stopped)
        #expect(model.snapshot.plan.rootID == "main")
        #expect(!model.snapshot.isFinal)
        #expect(model.report == nil)
        let version = model.snapshot.version
        let stats = model.frameStats
        input.yield(Self.text)
        input.finish()
        await Task.yield()
        #expect(model.snapshot.version == version)
        #expect(model.frameStats == stats)
    }

    @Test("Task cancellation stops the stream like cancel()")
    func taskCancellation() async {
        let model = Self.model()
        let (text, input) = AsyncThrowingStream.makeStream(of: String.self)
        let run = Task { await model.run(text, mode: .jsonl) }
        input.yield(Self.root)
        _ = await observe({ model.snapshot }, until: { $0.spec.root == "main" })
        run.cancel()
        await run.value
        #expect(model.phase == .stopped)
        #expect(model.snapshot.spec.root == "main")
    }

    @Test("A throwing stream journals one unrecoverable (type name only) and keeps the snapshot")
    func throwingStream() async {
        let model = Self.model()
        let (text, input) = AsyncThrowingStream.makeStream(of: String.self)
        let run = Task { await model.run(text, mode: .jsonl) }
        input.yield(Self.root)
        _ = await observe({ model.snapshot }, until: { $0.spec.root == "main" })
        input.finish(throwing: StreamTestError())
        await run.value
        #expect(model.phase == .stopped)
        #expect(model.journal == [.unrecoverable("StreamTestError")])
        #expect(model.snapshot.journal == model.journal)
        #expect(model.snapshot.spec.root == "main")
    }

    @Test("While streaming, /state is mirrored into the store; afterwards the store is the user's")
    func stateMirroring() async throws {
        let model = Self.model()
        let subscription = await model.store.subscribe(bufferingPolicy: .unbounded)
        let (text, input) = AsyncThrowingStream.makeStream(of: String.self)
        let run = Task { await model.run(text, mode: .jsonl) }
        input.yield(#"{"op":"add","path":"/state","value":{"n":1}}"# + "\n")
        input.yield(#"{"op":"replace","path":"/state/n","value":2}"# + "\n")
        input.finish()
        await run.value
        var states: [JSONValue] = []
        for await snapshot in subscription.updates {
            states.append(snapshot.state)
            if snapshot.state == ["n": 2] { break }
        }
        #expect(states == [["n": 1], ["n": 2]])
        #expect(await model.store.snapshot.state == model.snapshot.spec.state ?? [:])
        await model.store.set("/n", 5)
        #expect(await model.store.snapshot.state == ["n": 5])
    }

    @Test("Mixed mode: text is ignored, fenced patches apply")
    func mixedMode() async {
        let model = Self.model()
        let (text, input) = AsyncThrowingStream.makeStream(of: String.self)
        let run = Task { await model.run(text, mode: .mixed) }
        input.yield("Here you go:\n```spec\n" + Self.root + Self.main + Self.text + "```\nDone.\n")
        input.finish()
        await run.value
        #expect(model.phase == .final)
        #expect(model.snapshot.plan.order == ["main", "t"])
        #expect(model.journal.isEmpty)
    }

    @Test("A second run after the end starts from the initial spec")
    func rerun() async {
        let model = Self.model()
        for root in ["a", "b"] {
            let (text, input) = AsyncThrowingStream.makeStream(of: String.self)
            input.yield(#"{"op":"add","path":"/state/"# + root + #"","value":1}"# + "\n")
            input.finish()
            await model.run(text, mode: .jsonl)
            #expect(model.phase == .final)
            #expect(model.snapshot.spec.state == [root: 1])
        }
    }
}
