// Owner: jr-3. The computed label of every element in the upstream examples.
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI

/// Lists `AccessibilityAudit` entries for the eight upstream specs. A control without a
/// label is marked with a symbol and the word "Missing". VoiceOver and Full Keyboard
/// Access passes stay manual (the user's checks).
struct AccessibilityPage: GalleryPage {
    static let title = "Labels audit"
    static let group = GalleryGroup.accessibility

    /// Loaded once, on first appearance (see `FixtureSpecsPage.models`).
    @State private var rows: [(String, [AccessibilityAudit.Entry])]?

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note:
                "The label each element gets from its spec: label, title, text, alt, name, trigger."
        ) {
            ForEach(rows ?? [], id: \.0) { file, entries in
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(entries, id: \.self) { entry in
                        HStack(spacing: 8) {
                            Text(entry.type).font(.system(size: 12, weight: .medium))
                                .frame(width: 110, alignment: .leading)
                            Text(entry.id).font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 150, alignment: .leading)
                            if entry.isMissingLabel {
                                Label("Missing", systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                            } else {
                                Text(entry.label ?? "—").font(.system(size: 12))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if rows == nil { rows = AccessibilityPage.load() }
        }
    }

    static func load() -> [(String, [AccessibilityAudit.Entry])] {
        FixtureSpecsPage.loadModels().map { file, model in
            (file, AccessibilityAudit.entries(in: model.walk()))
        }
    }
}
