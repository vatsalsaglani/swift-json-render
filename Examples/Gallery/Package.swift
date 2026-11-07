// swift-tools-version: 6.2
// The Gallery app: every component, every preset, a streaming replay, and headless snapshots.
// Separate from the root manifest so consumers never build it.
import PackageDescription

let package = Package(
    name: "Gallery",
    platforms: [.macOS(.v14)],
    dependencies: [.package(name: "swift-json-render", path: "../..")],
    targets: [
        .executableTarget(
            name: "Gallery",
            dependencies: [
                .product(name: "JSONRenderCore", package: "swift-json-render"),
                .product(name: "JSONRenderSwiftUI", package: "swift-json-render"),
                .product(name: "JSONRenderStandardCatalog", package: "swift-json-render"),
                .product(name: "JSONRenderCharts", package: "swift-json-render"),
            ],
            path: "Sources/Gallery",
            resources: [.copy("Specs")],
            swiftSettings: [.swiftLanguageMode(.v6), .enableUpcomingFeature("ExistentialAny")])
    ]
)
