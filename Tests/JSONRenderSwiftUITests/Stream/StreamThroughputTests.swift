import JSONRenderCore
import Testing

@testable import JSONRenderSwiftUI

@MainActor
@Suite("Stream throughput")
struct StreamThroughputTests {
    @Test("1,000 patches in about 1 s against 16 ms ticks: at most one publish per tick")
    func atMostOnePublishPerTick() async {
        let clock = ManualFrameClock()
        let coalescer = FrameCoalescer<SpecSnapshot>(clock: clock)
        let store = SpecStore(catalog: Catalog())
        await store.apply([
            SpecPatch(op: .add, path: "/root", value: "c1"),
            SpecPatch(
                op: .add, path: "/elements/c1", value: ["type": "LineChart", "props": ["data": []]]),
        ])
        let snapshots = await store.snapshots()
        let versions = Recorder<UInt64>()
        let consumer = Task { @MainActor in
            await coalescer.run(snapshots) { versions.values.append($0.version) }
        }
        let ticker = Task { @MainActor in
            let wall = ContinuousClock()
            while !Task.isCancelled {
                do { try await wall.sleep(for: .milliseconds(16)) } catch { return }
                clock.tick()
            }
        }
        let started = ContinuousClock.now
        let producer = Task.detached {
            var decoder = SpecStreamDecoder(mode: .jsonl)
            let wall = ContinuousClock()
            for chunk in 0..<100 {
                var text = ""
                for row in 0..<10 {
                    let x = chunk * 10 + row
                    text +=
                        #"{"op":"add","path":"/elements/c1/props/data/-","value":{"x":"# + "\(x)"
                        + #","y":"#
                        + "\(x % 13)" + "}}\n"
                }
                await store.apply(decoder.push(text))
                try? await wall.sleep(for: .milliseconds(10))
            }
            _ = await store.finish()
        }
        await producer.value
        await consumer.value
        ticker.cancel()
        await ticker.value
        let elapsed = ContinuousClock.now - started
        let ticks = clock.tickCount
        let fromTicks = coalescer.published - coalescer.fallbackPublished
        print(
            "StreamThroughput: patches=1000 elapsed=\(elapsed) ticks=\(ticks) published=\(coalescer.published) fallbackPublished=\(coalescer.fallbackPublished) dropped=\(coalescer.dropped)"
        )
        let final = await store.current
        #expect(final.isFinal)
        #expect(versions.values.last == final.version)
        #expect(final.spec.elements["c1"]?.props["data"]?.arrayValue?.count == 1_000)
        // Tick publishes never exceed ticks; the source end adds one.
        #expect(fromTicks <= ticks + 1)
        #expect(coalescer.published <= ticks + coalescer.fallbackPublished + 1)
        #expect(coalescer.published + coalescer.dropped <= 102)
    }
}
