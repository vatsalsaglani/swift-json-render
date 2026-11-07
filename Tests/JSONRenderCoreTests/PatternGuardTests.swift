import Testing

@testable import JSONRenderCore

/// The `pattern` ReDoS guard (fix round 1, B1).
@Suite("Pattern guard")
struct PatternGuardTests {
    @Test(
        "Nested quantifiers are refused",
        arguments: [
            #"(a+)+"#, #"(\w+\s?)*"#, #"(a*)*"#, #"(x?)+"#, #"^(a+)+$"#, #"((a+)b){2,}"#,
            #"(?:a+)+"#,
        ])
    func refused(_ pattern: String) {
        #expect(PatternGuard.hasNestedQuantifier(pattern))
    }

    @Test(
        "Escapes, classes and normal patterns are allowed",
        arguments: [
            #"\(a+\)+"#, #"[(a+)]+"#, #"^[a-z]+$"#, #"^\d{3}-\d{4}$"#,
            #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, #"^\d+(\.\d+)?$"#, #"[\]a+]+"#, #"(ab)+"#,
        ])
    func allowed(_ pattern: String) {
        #expect(!PatternGuard.hasNestedQuantifier(pattern))
    }

    @Test(
        "Malformed patterns never trap",
        arguments: ["(", ")", "\\", "[", "a{", "a{1,", "((((", "))+", "[]", "{9999999999}"])
    func malformed(_ pattern: String) {
        _ = PatternGuard.hasNestedQuantifier(pattern)
    }

    @Test("Length caps")
    func caps() {
        let long = String(repeating: "a", count: PatternGuard.maxPatternLength + 1)
        #expect(PatternGuard.refusal(pattern: long, value: "a") == .patternTooLong)
        let value = String(repeating: "a", count: PatternGuard.maxValueLength + 1)
        #expect(PatternGuard.refusal(pattern: "a", value: value) == .valueTooLong)
        #expect(PatternGuard.refusal(pattern: "^a+$", value: "aaa") == nil)
    }

    @Test("Regression: ^(\\w+\\s?)*$ against 40 characters returns at once")
    func regression() {
        let check = ValidationCheck.pattern(#"^(\w+\s?)*$"#, "m")
        let value = JSONValue.string(String(repeating: "a", count: 39) + "!")
        let clock = ContinuousClock()
        let start = clock.now
        let result = Validator.runCheck(check, value: value, state: [:])
        #expect(clock.now - start < .seconds(1))
        #expect(!result.valid)
        #expect(result.patternRefused)
        #expect(result.patternRefusal == .nestedQuantifier)
    }

    @Test("An allowed pattern still runs and is not flagged")
    func allowedRuns() {
        let result = Validator.runCheck(.pattern("^[a-z]+$"), value: "abc", state: [:])
        #expect(result.valid && !result.patternRefused)
    }
}
