import Foundation
import Testing

@testable import JSONRenderCore

/// `upstream/validator/*`: `validateSpec` and `autoFixSpec`, with the Swift extension
/// checks off (`ValidateSpecOptions.upstream`).
@Suite("Spec validator parity (upstream/validator)")
struct SpecValidatorParityTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let kind: String
        let spec: JSONValue
        let expected: JSONValue
        var testDescription: String { "validator/\(name)" }
    }

    static func cases() -> [Case] {
        guard case .array(let rows)? = try? ParityFixtures.json("validator/index.json") else {
            return []
        }
        return rows.compactMap { row in
            guard let name = row["name"]?.stringValue, let kind = row["kind"]?.stringValue,
                let input = row["input"]?.stringValue,
                let expected = row["expected"]?.stringValue,
                let spec = try? ParityFixtures.json("validator/\(input)"),
                let result = try? ParityFixtures.json("validator/\(expected)")
            else { return nil }
            return Case(name: name, kind: kind, spec: spec, expected: result)
        }
    }

    @Test("Replays the case", arguments: SpecValidatorParityTests.cases())
    func replay(_ fixture: Case) throws {
        let spec = try Spec(json: fixture.spec)
        let options = fixture.expected["options"]
        if fixture.kind == "autofix" {
            let result = Catalog.autoFixReport(spec, lossy: options?["lossy"] != .bool(false))
            #expect(.array(result.messages.map(JSONValue.string)) == fixture.expected["fixes"])
            let details = result.fixes.map {
                JSONValue.object(["message": .string($0.message), "lossy": .bool($0.lossy)])
            }
            #expect(.array(details) == fixture.expected["fixDetails"])
            let fixed = try Spec(json: fixture.expected["fixed"] ?? .null)
            #expect(result.spec == fixed)
            let after = Catalog().validate(result.spec, options: .upstream())
            #expect(after.valid == fixture.expected["validAfterFix"]?.boolValue)
            return
        }
        let report = Catalog().validate(
            spec, options: .upstream(checkOrphans: options?["checkOrphans"] == .bool(true)))
        #expect(report.valid == fixture.expected["valid"]?.boolValue)
        let codes = report.issues.map(\.code.rawValue)
        if fixture.expected["partial"] == .bool(true) {
            for case .string(let code) in fixture.expected["asserted"]?.arrayValue ?? [] {
                #expect(codes.contains(code), "missing \(code)")
            }
            for (code, count) in fixture.expected["counts"]?.objectValue ?? [:] {
                #expect(Double(codes.filter { $0 == code }.count) == count.numberValue, "\(code)")
            }
        }
        // The full issue list must also match: partial cases record what upstream produced.
        #expect(.array(codes.sorted().map(JSONValue.string)) == fixture.expected["codes"])
        let issues = report.issues.map(Self.json).sorted {
            $0.debugDescription < $1.debugDescription
        }
        let expectedIssues = (fixture.expected["issues"]?.arrayValue ?? [])
            .map { issue -> JSONValue in
                var members = issue.objectValue ?? [:]
                members["message"] = .string(
                    Self.comparable(
                        issue["code"]?.stringValue ?? "", issue["message"]?.stringValue ?? ""))
                return .object(members)
            }
            .sorted { $0.debugDescription < $1.debugDescription }
        #expect(issues == expectedIssues)
    }

    /// The issue as the fixture writes it. The `invalid_visible` message quotes the
    /// condition with `JSON.stringify` in insertion order, which Swift values do not keep;
    /// for that code only the text outside the quoted condition is compared (the fixture
    /// README marks messages as informative).
    static func json(_ issue: SpecIssue) -> JSONValue {
        var members: [String: JSONValue] = [
            "code": .string(issue.code.rawValue), "severity": .string(issue.severity.rawValue),
            "message": .string(comparable(issue.code.rawValue, issue.message)),
        ]
        if let key = issue.elementKey { members["elementKey"] = .string(key) }
        return .object(members)
    }

    @Test("Every upstream code is covered by a fixture")
    func coverage() {
        let covered = Set(Self.cases().flatMap { $0.expected["codes"]?.arrayValue ?? [] })
        for code in SpecIssue.Code.allCases where code.isUpstream {
            #expect(covered.contains(.string(code.rawValue)), "\(code)")
        }
    }

    static func comparable(_ code: String, _ message: String) -> String {
        guard code == "invalid_visible", let start = message.range(of: "condition: "),
            let end = message.range(of: ". Valid forms:")
        else { return message }
        return String(message[..<start.upperBound]) + "<condition>"
            + String(message[end.lowerBound...])
    }

    @Test("invalid_visible quotes the condition with sorted keys")
    func invalidVisibleMessage() throws {
        let spec = try Spec(json: [
            "root": "r",
            "elements": ["r": ["type": "T", "props": [:], "visible": ["when": "/x", "is": 1]]],
        ])
        let issue = Catalog().validate(spec, options: .upstream()).issues.first
        #expect(issue?.message.contains(#"condition: {"is":1,"when":"/x"}. Valid forms"#) == true)
    }
}
