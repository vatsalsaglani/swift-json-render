// Owner: jr-3 (Gallery shell). Shared page building blocks.
import Foundation
import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI
import SwiftUI

/// The catalog the Gallery renders with: the standard catalog plus the two `$computed`
/// functions the upstream "Cascading Selects" example registers.
@MainActor
enum GalleryCatalog {
    static let standard: Catalog = {
        var catalog = (try? Catalog.standard) ?? Catalog()
        catalog.function("citiesForCountry", description: "Cities for a country") { args in
            let cities: [String: [String]] = [
                "US": ["New York", "Chicago", "Austin"], "Canada": ["Toronto", "Vancouver"],
                "UK": ["London", "Leeds"], "Germany": ["Berlin", "Munich"],
                "Japan": ["Tokyo", "Osaka"],
            ]
            let country = (args["country"] ?? nil)?.stringValue ?? ""
            return .array((cities[country] ?? []).map(JSONValue.string))
        }
        catalog.function("formatAddress", description: "City and country on one line") { args in
            let city = (args["city"] ?? nil)?.stringValue ?? ""
            let country = (args["country"] ?? nil)?.stringValue ?? ""
            if city.isEmpty && country.isEmpty { return .string("No address yet") }
            return .string([city, country].filter { !$0.isEmpty }.joined(separator: ", "))
        }
        return catalog
    }()
}

extension EnvironmentValues {
    /// `true` while the snapshot mode renders a page (no scroll view, fixed width).
    @Entry var gallerySnapshotMode: Bool = false
}

/// The frame of every page: a title, a one-line note, then sections 20 pt apart.
struct GalleryPageLayout<Content: View>: View {
    let title: String
    let note: String
    @ViewBuilder let content: Content
    @Environment(\.gallerySnapshotMode) private var snapshotMode

    var body: some View {
        if snapshotMode {
            column
        } else {
            ScrollView { column }
        }
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 20, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(note).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One labelled example: a caption and the spec rendered with the standard catalog.
struct SpecExample: View {
    let caption: String
    private let decoded: Result<Spec, SpecDecodeError>

    init(_ caption: String, json: String) {
        self.caption = caption
        do {
            decoded = .success(try Spec.decode(Data(json.utf8)).spec)
        } catch {
            decoded = .failure(error)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(caption.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            switch decoded {
            case .success(let spec):
                JSONRenderView(spec: spec, catalog: GalleryCatalog.standard)
            case .failure(let error):
                Text("Spec error: \(error.message)").font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
    }
}

/// The repository root, found from this file's path (the Gallery runs from a checkout).
enum GalleryRepository {
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Sources/Gallery/Support
        .deletingLastPathComponent()  // Sources/Gallery
        .deletingLastPathComponent()  // Sources
        .deletingLastPathComponent()  // Examples/Gallery
        .deletingLastPathComponent()  // Examples
        .deletingLastPathComponent()  // repository root
}
