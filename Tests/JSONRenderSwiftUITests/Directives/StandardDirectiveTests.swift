import Foundation
import JSONRenderCore
import JSONRenderStandardCatalog
import Testing

@Suite struct StandardDirectiveTests {
    let catalog: Catalog

    init() throws {
        catalog = try Catalog.standard
    }

    private func resolve(_ value: JSONValue, state: JSONValue = [:]) -> JSONValue? {
        var resolver = PropResolver(
            context: PropResolutionContext(
                state: state, functions: catalog.functions, directives: catalog.directives))
        return resolver.resolveValue(value)
    }

    @Test func registeredInOrderAndPrompted() {
        #expect(catalog.directives.orderedNames == ["$format", "$count", "$join", "$pluralize"])
        let prompt = catalog.prompt()
        #expect(prompt.contains("CUSTOM DYNAMIC VALUES:"))
        #expect(
            prompt.contains(
                "- $pluralize (Select singular/plural/zero form based on count. Output: \"3 items\", \"1 item\", or \"no items\".): { $pluralize: unknown, zero?: string, one: string, other: string }"
            ))
        #expect(
            prompt.contains("- $count (Get the length of an array or string.): { $count: unknown }")
        )
    }

    @Test func countArraysAndStrings() {
        #expect(resolve(["$count": ["$state": "/items"]], state: ["items": [1, 2, 3]]) == 3)
        #expect(resolve(["$count": "héllo"]) == 5)
        #expect(resolve(["$count": "👍"]) == 2)  // UTF-16 units, as JavaScript
        #expect(resolve(["$count": 42]) == 0)
        #expect(resolve(["$count": ["$state": "/missing"]]) == 0)
    }

    @Test func joinWithSeparatorAndNulls() {
        #expect(resolve(["$join": ["a", "b", "c"]]) == "a, b, c")
        #expect(resolve(["$join": ["a", .null, 3], "separator": " / "]) == "a /  / 3")
        #expect(resolve(["$join": ["$state": "/tags"]], state: ["tags": ["x", "y"]]) == "x, y")
        #expect(resolve(["$join": ["$state": "/missing"]]) == "")
        #expect(resolve(["$join": .null]) == "")
        #expect(resolve(["$join": 7]) == "7")
    }

    @Test func pluralizeForms() {
        let base: [String: JSONValue] = ["one": "item", "other": "items"]
        func call(_ count: JSONValue, zero: JSONValue? = nil) -> JSONValue? {
            var raw = base
            raw["$pluralize"] = count
            if let zero { raw["zero"] = zero }
            return resolve(.object(raw))
        }
        #expect(call(1) == "1 item")
        #expect(call(3) == "3 items")
        #expect(call(0) == "0 items")
        #expect(call(0, zero: "no items") == "no items")
        #expect(call("2") == "2 items")
        #expect(call("abc") == "0 items")
        #expect(call(1.5) == "1.5 items")
    }

    @Test func formatNumbers() {
        let us: JSONValue = "en-US"
        #expect(resolve(["$format": "currency", "value": 1234.5, "locale": us]) == "$1,234.50")
        #expect(
            resolve(["$format": "currency", "value": 9, "currency": "EUR", "locale": us]) == "€9.00"
        )
        #expect(resolve(["$format": "number", "value": 1234.5678, "locale": us]) == "1,234.568")
        #expect(
            resolve(["$format": "number", "value": 1_250_000, "notation": "compact", "locale": us])
                == "1.3M")
        #expect(resolve(["$format": "percent", "value": 0.256, "locale": us]) == "26%")
        #expect(resolve(["$format": "number", "value": "abc", "locale": us]) == nil)
        #expect(
            resolve(
                ["$format": "number", "value": ["$state": "/n"], "locale": us], state: ["n": 12])
                == "12")
    }

    @Test func formatRelativeDates() {
        let now = 1_700_000_000_000.0
        func relative(_ offset: Double) -> JSONValue? {
            resolve([
                "$format": "date", "value": .number(now - offset), "style": "relative",
                "now": .number(now),
            ])
        }
        #expect(relative(0) == "just now")
        #expect(relative(42_000) == "42s ago")
        #expect(relative(5 * 60_000 + 59_000) == "5m ago")
        #expect(relative(3 * 3_600_000) == "3h ago")
        #expect(relative(3 * 86_400_000 + 5) == "3d ago")
        #expect(relative(-2 * 86_400_000) == "2d from now")
    }

    @Test func formatAbsoluteDate() {
        let value = resolve([
            "$format": "date", "value": "2026-11-07T12:00:00Z", "locale": "en-US",
        ])
        guard case .string(let text)? = value else {
            Issue.record("expected a string")
            return
        }
        #expect(text.contains("2026"))
        #expect(resolve(["$format": "date", "value": "not a date"]) == nil)
    }
}
