// swift-tools-version: 6.2
// Owner: the coordinator. Agents never edit this file; a needed target change is a stop-and-report.
import CompilerPluginSupport
import PackageDescription

let strict: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "swift-json-render",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "JSONRenderCore", targets: ["JSONRenderCore"]),
        .library(name: "JSONRenderSwiftUI", targets: ["JSONRenderSwiftUI"]),
        .library(name: "JSONRenderStandardCatalog", targets: ["JSONRenderStandardCatalog"]),
        .library(name: "JSONRenderCharts", targets: ["JSONRenderCharts"]),
        .library(name: "JSONRenderRemoteImages", targets: ["JSONRenderRemoteImages"]),
        .library(name: "JSONRenderCompose", targets: ["JSONRenderCompose"]),
        .library(name: "JSONRenderClient", targets: ["JSONRenderClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"605.0.0")
    ],
    targets: [
        // Foundation only. Linux-capable. No SwiftUI, no network.
        .target(name: "JSONRenderCore", swiftSettings: strict),
        .target(name: "JSONRenderSwiftUI", dependencies: ["JSONRenderCore"], swiftSettings: strict),
        .target(
            name: "JSONRenderStandardCatalog",
            dependencies: ["JSONRenderCore", "JSONRenderSwiftUI"],
            swiftSettings: strict),
        .target(
            name: "JSONRenderCharts", dependencies: ["JSONRenderCore", "JSONRenderSwiftUI"],
            swiftSettings: strict),
        // Optional: the only image-network code. Hosts opt in.
        .target(
            name: "JSONRenderRemoteImages", dependencies: ["JSONRenderCore", "JSONRenderSwiftUI"],
            swiftSettings: strict),
        // Optional: the only Decisions API code. Hosts opt in.
        .target(name: "JSONRenderCompose", dependencies: ["JSONRenderCore"], swiftSettings: strict),
        .macro(
            name: "JSONRenderMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            swiftSettings: strict),
        .target(
            name: "JSONRenderClient", dependencies: ["JSONRenderCore", "JSONRenderMacros"],
            swiftSettings: strict),
        .testTarget(
            name: "JSONRenderCoreTests", dependencies: ["JSONRenderCore"],
            swiftSettings: strict),
    ]
)
