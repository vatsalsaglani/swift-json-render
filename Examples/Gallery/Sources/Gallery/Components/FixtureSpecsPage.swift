// Owner: jr-3. The eight upstream example specs: the "no fallback block" check.
import Foundation
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI

/// Renders `Tests/ParityFixtures/upstream/specs/*.json`. When a spec draws a fallback block
/// (unknown type, missing element, cycle, too deep), the page prints `FALLBACK <file> <id>`
/// to standard error so a gate can grep it.
struct FixtureSpecsPage: GalleryPage {
    static let title = "Upstream examples"
    static let group = GalleryGroup.components

    static let files = [
        "confetti", "user-profile-card", "settings-form", "pricing-table", "status-dashboard",
        "feature-comparison", "registration-form", "cascading-selects",
    ]

    @State private var models: [(String, RenderModel)] = FixtureSpecsPage.loadModels()

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note: "The eight upstream example specs, rendered with Catalog.standard."
        ) {
            ForEach(models, id: \.0) { file, model in
                VStack(alignment: .leading, spacing: 8) {
                    Text(file.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    JSONRenderView(model: model)
                }
                .onAppear { FixtureSpecsPage.report(file: file, model: model) }
            }
        }
    }

    static func loadModels() -> [(String, RenderModel)] {
        let folder = GalleryRepository.root
            .appendingPathComponent("Tests/ParityFixtures/upstream/specs")
        return files.compactMap { file in
            let url = folder.appendingPathComponent(file + ".json")
            do {
                let spec = try Spec.decode(try Data(contentsOf: url)).spec
                return (file, RenderModel(spec: spec, catalog: GalleryCatalog.standard))
            } catch {
                FileHandle.standardError.write(
                    Data("FALLBACK \(file) <unreadable: \(error)>\n".utf8))
                return nil
            }
        }
    }

    static func report(file: String, model: RenderModel) {
        for warning in model.walk().fallbacks {
            FileHandle.standardError.write(
                Data("FALLBACK \(file) \(warning.elementID) \(warning)\n".utf8))
        }
    }
}
