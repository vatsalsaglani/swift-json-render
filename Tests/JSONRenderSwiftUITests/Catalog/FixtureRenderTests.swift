import Foundation
import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI
import Testing

/// The eight upstream example specs render with `Catalog.standard` and no fallback block.
///
/// Until jr-3b's group 2 merges, the only allowed fallbacks are unknown types that group 2
/// will register; after the merge the list must be empty.
@Suite struct FixtureRenderTests {
    static let group2Names: Set<String> = [
        "Image", "Avatar", "Carousel", "Table", "Progress", "Spinner", "Button", "Link", "Input",
        "Textarea", "Select", "Checkbox", "Radio", "Switch", "Slider", "Toggle", "ToggleGroup",
        "ButtonGroup",
    ]

    @Test(arguments: Fixtures.specNames)
    func noFallbackBlocks(_ fixture: String) throws {
        let spec = try Fixtures.spec(fixture)
        let catalog = try Scripts.catalog()
        let walk = RenderWalk(
            spec: spec, plan: RenderPlan(spec: spec), state: spec.state ?? [:], catalog: catalog)
        let registered = Set(catalog.componentNames)
        for warning in walk.fallbacks {
            guard case .unknownType(_, let type) = warning, Self.group2Names.contains(type),
                !registered.contains(type)
            else {
                Issue.record("fallback in \(fixture): \(warning)")
                continue
            }
        }
        let pending = walk.fallbacks.compactMap { warning -> String? in
            if case .unknownType(let id, let type) = warning { return "\(id):\(type)" }
            return nil
        }
        if !pending.isEmpty { print("FIXTURE \(fixture) waits for group 2: \(pending)") }
    }

    /// Times `ElementResolution.resolve` for every drawn element of the eight specs and
    /// reports the p95 (the signposted work per element).
    @Test func resolutionTimeP95() throws {
        let catalog = try Scripts.catalog()
        var samples: [Duration] = []
        let clock = ContinuousClock()
        for fixture in Fixtures.specNames {
            let spec = try Fixtures.spec(fixture)
            let state = spec.state ?? [:]
            let walk = RenderWalk(
                spec: spec, plan: RenderPlan(spec: spec), state: state, catalog: catalog)
            for element in walk.elements {
                guard let raw = spec.elements[element.id] else { continue }
                for _ in 0..<50 {
                    let start = clock.now
                    _ = ElementResolution.resolve(
                        element: raw, scope: element.scope, state: state, catalog: catalog)
                    samples.append(clock.now - start)
                }
            }
        }
        samples.sort()
        let p95 = samples[Int(Double(samples.count - 1) * 0.95)]
        print("jsonrender.render.element p95 over \(samples.count) samples: \(p95)")
        #expect(p95 < .milliseconds(2))
    }
}
