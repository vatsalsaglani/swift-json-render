import Foundation
import Testing

/// The link map at source level: only `JSONRenderCompose` and `JSONRenderRemoteImages` may
/// name a network API. Walks `Sources/` from this file's path, so it also runs on Linux.
/// (CI adds an object-file `nm` check; this test is the source check.)
@Suite("Network boundary")
struct NetworkBoundaryTests {
    static let sources: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // JSONRenderCoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // package root
        .appendingPathComponent("Sources")

    static let networkTargets: Set<String> = ["JSONRenderCompose", "JSONRenderRemoteImages"]

    static let forbidden = [
        "URLSession", "URLRequest", "FoundationNetworking", "NWConnection", "import Network",
        "NSURLConnection", "URLSessionWebSocketTask", "WKWebView",
    ]

    /// Every `.swift` file under a target folder, with its lines.
    static func swiftFiles(in target: String) throws -> [(path: String, lines: [Substring])] {
        let root = sources.appendingPathComponent(target)
        guard
            let enumerator = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: nil)
        else { return [] }
        var files: [(String, [Substring])] = []
        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = String(decoding: try Data(contentsOf: url), as: UTF8.self)
            let relative = url.path.components(separatedBy: "/Sources/").last ?? url.path
            files.append((relative, text.split(separator: "\n", omittingEmptySubsequences: false)))
        }
        return files.sorted { $0.0 < $1.0 }
    }

    static func targets() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: sources.path)
            .filter { !$0.hasPrefix(".") }
            .sorted()
    }

    @Test("Sources holds the expected targets")
    func targetsFound() throws {
        let targets = try Self.targets()
        #expect(targets.contains("JSONRenderCore"))
        #expect(targets.contains("JSONRenderCompose"))
        #expect(targets.count >= 5)
    }

    @Test("No network symbol outside JSONRenderCompose and JSONRenderRemoteImages")
    func noNetworkOutsideBoundary() throws {
        var scanned = 0
        for target in try Self.targets() where !Self.networkTargets.contains(target) {
            for file in try Self.swiftFiles(in: target) {
                scanned += 1
                for (number, line) in file.lines.enumerated() {
                    for symbol in Self.forbidden where line.contains(symbol) {
                        Issue.record("\(file.path):\(number + 1) names \(symbol)")
                    }
                }
            }
        }
        #expect(scanned > 50)
    }

    @Test("JSONRenderCompose has no SwiftUI and no print")
    func composeIsQuiet() throws {
        let files = try Self.swiftFiles(in: "JSONRenderCompose")
        #expect(!files.isEmpty)
        for file in files {
            for (number, line) in file.lines.enumerated() {
                for symbol in ["import SwiftUI", "print(", "os_log", "Logger("]
                where line.contains(symbol) {
                    Issue.record("\(file.path):\(number + 1) names \(symbol)")
                }
            }
        }
    }

    @Test("Only OpenAIDecisionsEvaluator builds a URLRequest in JSONRenderCompose")
    func oneRequestBuilder() throws {
        for file in try Self.swiftFiles(in: "JSONRenderCompose")
        where file.lines.contains(where: { $0.contains("URLRequest(") }) {
            #expect(file.path == "JSONRenderCompose/OpenAIDecisionsEvaluator.swift")
        }
    }
}
