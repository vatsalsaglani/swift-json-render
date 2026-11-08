import Foundation
import JSONRenderCompose
import JSONRenderCore

/// One `case.json` scenario.
struct ComposeCase: Sendable, CustomStringConvertible {
    let folder: String
    let json: JSONValue

    var description: String { folder }
    var candidatesFolder: String { json["candidates"]?.stringValue ?? folder }
    var catalogName: String { json["catalog"]?.stringValue ?? "jev" }
    var prompt: String { json["prompt"]?.stringValue ?? "" }
    var initialState: JSONValue? { json["initialState"] }
    var stopReason: String { json["stopReason"]?.stringValue ?? "" }
    var requests: Int { Int(json["requests"]?.numberValue ?? -1) }
    var elements: Int? { json["elements"]?.numberValue.map { Int($0) } }
    var refused: [String] { json["refused"]?.arrayValue?.compactMap(\.stringValue) ?? [] }
    var fallbacks: [String] { json["fallbacks"]?.arrayValue?.compactMap(\.stringValue) ?? [] }
    var rootChildren: [String]? { json["rootChildren"]?.arrayValue?.compactMap(\.stringValue) }
    var transportFile: String? { json["transport"]?.stringValue }
}

/// Loads `Tests/ParityFixtures/compose`, located from this file's path (no bundle
/// resources), as `ParityFixtures.swift` does for the upstream fixtures.
enum ComposeFixtures {
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Support
        .deletingLastPathComponent()  // JSONRenderComposeTests
        .deletingLastPathComponent()  // Tests
        .appendingPathComponent("ParityFixtures")
        .appendingPathComponent("compose")

    /// The scenario folders listed in `README.md`.
    static let scenarioFolders = [
        "jev-preferences", "dashboard-24", "unavailable", "refusal-root", "low-confidence-order",
        "limit-density-sparse", "layout-cycle", "evaluator-429", "wrong-answer-names",
    ]

    static func data(_ relativePath: String) throws -> Data {
        try Data(contentsOf: root.appendingPathComponent(relativePath))
    }

    static func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path)
    }

    static func json(_ relativePath: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: data(relativePath))
    }

    static func candidates(_ folder: String) throws -> [CompositionCandidate] {
        try JSONDecoder().decode(
            [CompositionCandidate].self, from: data("\(folder)/candidates.json"))
    }

    static func response(_ relativePath: String) throws -> DecisionResponse {
        try JSONDecoder().decode(DecisionResponse.self, from: data(relativePath))
    }

    static func scenario(_ folder: String) throws -> ComposeCase {
        ComposeCase(folder: folder, json: try json("\(folder)/case.json"))
    }

    /// The recorded responses of a scenario, in request order.
    static func responses(_ folder: String) throws -> [DecisionResponse] {
        try ["select", "layout"].compactMap { round in
            let path = "\(folder)/\(round).response.json"
            return exists(path) ? try response(path) : nil
        }
    }

    static func spec(_ relativePath: String) throws -> Spec {
        try Spec.decode(data(relativePath)).spec
    }
}
