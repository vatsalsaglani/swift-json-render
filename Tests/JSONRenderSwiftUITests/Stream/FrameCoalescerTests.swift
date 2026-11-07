import Testing

@testable import JSONRenderSwiftUI

@MainActor
@Suite("FrameCoalescer")
struct FrameCoalescerTests {
    @Test("1,000 values between two ticks: 1 publish, 999 drops")
    func coalesces() {
        let coalescer = FrameCoalescer<Int>(clock: ManualFrameClock())
        coalescer.tick()
        for value in 1...1_000 { coalescer.offer(value) }
        coalescer.tick()
        #expect(coalescer.published == 1)
        #expect(coalescer.dropped == 999)
    }

    @Test("A value, a tick, the same value again: no second publish")
    func sameValue() {
        let coalescer = FrameCoalescer<Int>(clock: ManualFrameClock())
        coalescer.offer(7)
        coalescer.tick()
        coalescer.offer(7)
        coalescer.tick()
        #expect(coalescer.published == 1)
        coalescer.offer(8)
        coalescer.tick()
        #expect(coalescer.published == 2)
    }

    @Test("Without a tick, the 50 ms fallback publishes")
    func headlessFallback() async {
        let coalescer = FrameCoalescer<Int>(clock: ManualFrameClock())
        let (source, input) = AsyncStream.makeStream(of: Int.self)
        let (output, published) = AsyncStream.makeStream(of: Int.self)
        let run = Task { await coalescer.run(source) { published.yield($0) } }
        input.yield(42)
        var iterator = output.makeAsyncIterator()
        #expect(await iterator.next() == 42)
        #expect(coalescer.fallbackPublished == 1)
        input.finish()
        await run.value
        #expect(coalescer.published == 1)
    }

    @Test("Source end publishes the kept value at once")
    func sourceEndFlushes() async {
        let coalescer = FrameCoalescer<Int>(clock: ManualFrameClock(), fallbackDelay: nil)
        let (source, input) = AsyncStream.makeStream(of: Int.self)
        for value in 1...10 { input.yield(value) }
        input.finish()
        var last: Int?
        await coalescer.run(source) { last = $0 }
        #expect(last == 10)
        #expect(coalescer.published == 1)
        #expect(coalescer.dropped == 9)
    }

    @Test("Cancellation ends run and publishes nothing more")
    func cancellation() async {
        let coalescer = FrameCoalescer<Int>(clock: ManualFrameClock(), fallbackDelay: nil)
        let (source, input) = AsyncStream.makeStream(of: Int.self)
        let run = Task { await coalescer.run(source) { _ in } }
        input.yield(1)
        run.cancel()
        await run.value
        #expect(coalescer.published == 0)
    }
}
