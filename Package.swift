// swift-tools-version: 6.2
// Owner: the coordinator. Agents never edit this file; a needed target change is a stop-and-report.
import CompilerPluginSupport
import PackageDescription

let strict: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

// Linux builds and tests the platform-neutral targets only (Core, Compose, Client, Macros).
// SwiftUI, Swift Charts and the image loader are Apple-only.
#if os(Linux)
    let includeAppleTargets = false
#else
    let includeAppleTargets = true
#endif

var products: [Product] = [
    .library(name: "JSONRenderCore", targets: ["JSONRenderCore"]),
    .library(name: "JSONRenderCompose", targets: ["JSONRenderCompose"]),
    .library(name: "JSONRenderClient", targets: ["JSONRenderClient"]),
]

var targets: [Target] = [
    // Foundation only. Linux-capable. No SwiftUI, no network.
    .target(name: "JSONRenderCore", swiftSettings: strict),
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
    .testTarget(
        name: "JSONRenderMacroTests",
        dependencies: [
            "JSONRenderMacros",
            "JSONRenderClient",
            .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
        ],
        swiftSettings: strict),
    .testTarget(
        name: "JSONRenderComposeTests", dependencies: ["JSONRenderCompose", "JSONRenderCore"],
        swiftSettings: strict),
]

if includeAppleTargets {
    products += [
        // One import for hosts: core, SwiftUI renderer and the standard catalog.
        .library(name: "JSONRender", targets: ["JSONRender"]),
        .library(name: "JSONRenderSwiftUI", targets: ["JSONRenderSwiftUI"]),
        .library(name: "JSONRenderStandardCatalog", targets: ["JSONRenderStandardCatalog"]),
        .library(name: "JSONRenderCharts", targets: ["JSONRenderCharts"]),
        .library(name: "JSONRenderRemoteImages", targets: ["JSONRenderRemoteImages"]),
    ]
    targets += [
        .target(
            name: "JSONRender",
            dependencies: ["JSONRenderCore", "JSONRenderSwiftUI", "JSONRenderStandardCatalog"],
            swiftSettings: strict),
        .target(name: "JSONRenderSwiftUI", dependencies: ["JSONRenderCore"], swiftSettings: strict),
        .target(
            name: "JSONRenderStandardCatalog",
            dependencies: ["JSONRenderCore", "JSONRenderSwiftUI", "JSONRenderClient"],
            swiftSettings: strict),
        .target(
            name: "JSONRenderCharts",
            dependencies: ["JSONRenderCore", "JSONRenderSwiftUI", "JSONRenderClient"],
            swiftSettings: strict),
        // Optional: the only image-network code. Hosts opt in.
        .target(
            name: "JSONRenderRemoteImages", dependencies: ["JSONRenderCore", "JSONRenderSwiftUI"],
            swiftSettings: strict),
        .testTarget(
            name: "JSONRenderSwiftUITests",
            dependencies: [
                "JSONRenderCore", "JSONRenderSwiftUI", "JSONRenderStandardCatalog",
                "JSONRenderClient",
            ],
            swiftSettings: strict),
        .testTarget(
            name: "JSONRenderChartsTests",
            dependencies: [
                "JSONRenderCore", "JSONRenderSwiftUI", "JSONRenderCharts", "JSONRenderClient",
            ],
            swiftSettings: strict),
    ]
}

let package = Package(
    name: "swift-json-render",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: products,
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"605.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: targets
)
