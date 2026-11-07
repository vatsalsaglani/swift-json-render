import Foundation
import Testing

@testable import JSONRenderCore

@Suite("JSONValue")
struct JSONValueTests {
    @Test(
        "JavaScript truthiness",
        arguments: [
            (JSONValue.null, false), (.bool(false), false), (.bool(true), true),
            (.number(0), false), (.number(-0.0), false), (.number(.nan), false),
            (.number(1), true), (.number(-1), true), (.string(""), false), (.string("0"), true),
            (.string("false"), true), (.array([]), true), (.object([:]), true),
        ])
    func truthiness(_ value: JSONValue, _ expected: Bool) {
        #expect(value.isTruthy == expected)
    }

    @Test(
        "JavaScript String() for numbers",
        arguments: [
            (0.0, "0"), (-0.0, "0"), (3.0, "3"), (-3.0, "-3"), (42.5, "42.5"), (0.1, "0.1"),
            (0.1 + 0.2, "0.30000000000000004"), (100.0, "100"), (1e20, "100000000000000000000"),
            (1e21, "1e+21"), (1.5e21, "1.5e+21"), (123_456_789_012.0, "123456789012"),
            (0.000001, "0.000001"), (1e-7, "1e-7"), (1.25e-7, "1.25e-7"), (-1e-7, "-1e-7"),
            (Double.nan, "NaN"), (Double.infinity, "Infinity"), (-Double.infinity, "-Infinity"),
            (1.7976931348623157e308, "1.7976931348623157e+308"), (5e-324, "5e-324"),
            (1234.5678, "1234.5678"), (0.5, "0.5"),
        ])
    func numberStrings(_ value: Double, _ expected: String) {
        #expect(JSONValue.number(value).jsString == expected)
    }

    @Test("JavaScript String() for other values")
    func otherStrings() {
        #expect(JSONValue.null.jsString == "null")
        #expect(JSONValue.bool(true).jsString == "true")
        #expect(JSONValue.string("hi").jsString == "hi")
        #expect(JSONValue.array([1, "a", .null, [2, 3]]).jsString == "1,a,,2,3")
        #expect(JSONValue.array([]).jsString == "")
        #expect(JSONValue.object(["a": 1]).jsString == "[object Object]")
    }

    @Test("Strict equality keeps undefined and null apart")
    func strictEquality() {
        #expect(JSONValue.null.strictEquals(.null))
        #expect(!JSONValue.null.strictEquals(nil))
        #expect(JSONValue.strictEquals(nil, nil))
        #expect(!JSONValue.strictEquals(nil, .null))
        #expect(!JSONValue.number(.nan).strictEquals(.number(.nan)))
        #expect(JSONValue.number(0).strictEquals(.number(-0.0)))
        #expect(!JSONValue.number(1).strictEquals(.string("1")))
        #expect(!JSONValue.bool(true).strictEquals(.number(1)))
        // Swift deviation: containers compare by value (upstream compares references).
        #expect(JSONValue.array([1, 2]).strictEquals(.array([1, 2])))
        #expect(JSONValue.object(["a": 1]).strictEquals(.object(["a": 1])))
    }

    @Test("Literals and subscripts")
    func literals() {
        let value: JSONValue = ["a": [1, 2.5, true, "x", nil]]
        #expect(value["a"]?[0] == .number(1))
        #expect(value["a"]?[1] == .number(2.5))
        #expect(value["a"]?[2] == .bool(true))
        #expect(value["a"]?[4] == .null)
        #expect(value["a"]?[5] == nil)
        #expect(value["missing"] == nil)
        #expect(JSONValue.string("s")["a"] == nil)
    }

    @Test("Codable round trip keeps null, numbers, nesting")
    func codableRoundTrip() throws {
        let text = #"{"a":null,"b":[1,2.5,-0.125,true,"x"],"c":{"d":{}},"e":[]}"#
        let decoded = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
        #expect(decoded["a"] == .null)
        #expect(decoded["b"] == [1, 2.5, -0.125, true, "x"])
        let reencoded = try JSONDecoder().decode(
            JSONValue.self, from: JSONEncoder().encode(decoded))
        #expect(reencoded == decoded)
    }

    /// Step 3 of the brief: every spec fixture survives decode → encode, compared as
    /// canonical JSON. `on` / `watch` single bindings are normalised to arrays first,
    /// because `UIElement` always encodes arrays.
    @Test(
        "Spec fixtures round-trip through Spec Codable",
        arguments: JSONValueTests.specFixtureFiles())
    func specRoundTrip(_ file: String) throws {
        let original = try ParityFixtures.json("specs/\(file)")
        let spec = try JSONDecoder().decode(Spec.self, from: ParityFixtures.data("specs/\(file)"))
        let reencoded = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(spec))
        #expect(try reencoded.canonicalText() == normalisedBindings(original).canonicalText())
    }

    static func specFixtureFiles() -> [String] {
        guard case .array(let rows)? = try? ParityFixtures.json("specs/index.json") else {
            return []
        }
        return rows.compactMap { $0["file"]?.stringValue }
    }

    private func normalisedBindings(_ spec: JSONValue) -> JSONValue {
        guard case .object(var members) = spec, case .object(var elements)? = members["elements"]
        else { return spec }
        for (id, element) in elements {
            guard case .object(var fields) = element else { continue }
            for key in ["on", "watch"] {
                guard case .object(var map)? = fields[key] else { continue }
                for (event, binding) in map {
                    if case .object = binding { map[event] = .array([binding]) }
                }
                fields[key] = .object(map)
            }
            elements[id] = .object(fields)
        }
        members["elements"] = .object(elements)
        return .object(members)
    }
}
