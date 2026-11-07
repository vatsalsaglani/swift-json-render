import Testing

@testable import JSONRenderCharts

@Suite("Nice numbers and the monotonic streaming domain")
struct DomainTests {
    @Test("Nice ceilings are 1, 2 or 5 times a power of ten")
    func niceCeil() {
        #expect(NiceScale.ceil(70) == 100)
        #expect(NiceScale.ceil(1_225) == 2_000)
        #expect(NiceScale.ceil(4.2) == 5)
        #expect(NiceScale.ceil(0.03) == 0.05)
        #expect(NiceScale.ceil(100) == 100)
        #expect(NiceScale.ceil(0) == 1)
    }

    @Test("Bar domains start at zero")
    func zeroBaseline() {
        #expect(NiceScale.domain(20...70) == 0...80)
        #expect(NiceScale.domain(20...70, fine: false) == 0...100)
        #expect(NiceScale.domain(-30...70) == -30...80)
        #expect(NiceScale.domain(0...11.2) == 0...12)
        #expect(NiceScale.domain(0...0) == 0...1)
    }

    @Test("Stepped domains fit the data without zero")
    func stepped() {
        let domain = NiceScale.domain(3.8...11.2, includeZero: false)
        #expect(domain.lowerBound <= 3.8 && domain.upperBound >= 11.2)
        #expect(domain.lowerBound > 0)
    }

    @Test("1,000 streamed points: non-decreasing, few distinct domains, one settle")
    func monotonic() {
        var domain = MonotonicDomain()
        var uppers: [Double] = []
        var lowers: [Double] = []
        for index in 1...1_000 {
            // A growing, noisy maximum.
            let value = Double(index) * 1.7 + Double(index % 7) * 3
            let range = domain.include(0...value)
            uppers.append(range.upperBound)
            lowers.append(range.lowerBound)
        }
        #expect(zip(uppers, uppers.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(zip(lowers, lowers.dropFirst()).allSatisfy { $0 >= $1 })
        let distinct = Set(uppers).count
        // log-many: 1-2-5 steps over about 3.3 decades.
        #expect(distinct <= 12)
        // A smaller final range settles once to a smaller nice domain.
        let before = domain.current
        let settled = domain.settle(0...400)
        #expect(settled == 0...400)
        #expect(before != settled)
        #expect(domain.current == settled)
    }

    @Test("A streaming domain never shrinks when data drops")
    func neverShrinks() {
        var domain = MonotonicDomain()
        domain.include(0...900)
        let after = domain.include(0...10)
        #expect(after == 0...1_000)
    }
}
