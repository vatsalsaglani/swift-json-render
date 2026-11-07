// Owner: jr-3 (Gallery shell). Seeded by the coordinator.
import AppKit
import JSONRenderSwiftUI
import SwiftUI

/// Entry point. `--list` prints the page titles; `--snapshot <dir>` writes PNGs headlessly.
/// Without arguments the app opens.
@main
enum GalleryMain {
    @MainActor
    static func main() {
        let arguments = CommandLine.arguments
        if arguments.contains("--list") {
            for page in GalleryPages.all {
                print("\(page.group.title) / \(page.title)")
            }
            print("\(GalleryPages.all.count) pages")
            exit(0)
        }
        if let index = arguments.firstIndex(of: "--snapshot") {
            let directory =
                arguments.indices.contains(index + 1) ? arguments[index + 1] : "/tmp/gallery-snaps"
            exit(Snapshotter.run(directory: directory))
        }
        GalleryApp.main()
    }
}

struct GalleryApp: App {
    var body: some Scene {
        WindowGroup("swift-json-render Gallery") {
            GalleryRoot()
                .frame(minWidth: 820, minHeight: 560)
        }
    }
}

/// The two packaged presets.
enum GalleryPreset: String, CaseIterable, Identifiable {
    case native, highContrast

    var id: String { rawValue }
    var title: String { self == .native ? "Native" : "High Contrast" }
    var theme: JSONRenderTheme { self == .native ? .native : .highContrast }
}

/// Sidebar of groups and pages; the detail shows one page with the toolbar's settings.
struct GalleryRoot: View {
    @State private var selection: String? = GalleryPages.all.first.map { "\($0)" }
    @State private var preset: GalleryPreset = .native
    @State private var scheme: ColorSchemeChoice = .system
    @State private var reduceMotion = false
    @State private var controlSize: ControlSizeChoice = .regular

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(GalleryGroup.allCases, id: \.self) { group in
                    let pages = GalleryPages.all.filter { $0.group == group }
                    if !pages.isEmpty {
                        Section(group.title) {
                            ForEach(pages.indices, id: \.self) { index in
                                Text(pages[index].title).tag(Optional("\(pages[index])"))
                            }
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            detail
                .toolbar { toolbar }
        }
        .preferredColorScheme(scheme.colorScheme)
    }

    @ViewBuilder
    private var detail: some View {
        if let page = GalleryPages.all.first(where: { "\($0)" == selection }) {
            let content = AnyView(page.init())
                .jsonRenderTheme(preset.theme)
                .controlSize(controlSize.size)
                .background(Color(nsColor: .windowBackgroundColor))
            if reduceMotion {
                content.jsonRenderTheme(\.motion, Motion.none)
            } else {
                content
            }
        } else {
            Text("Choose a page").foregroundStyle(.secondary)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Picker("Preset", selection: $preset) {
                ForEach(GalleryPreset.allCases) { Text($0.title).tag($0) }
            }
            .help("Theme preset")
            Picker("Appearance", selection: $scheme) {
                ForEach(ColorSchemeChoice.allCases) { Text($0.title).tag($0) }
            }
            .help("Light or dark appearance")
            Picker("Control size", selection: $controlSize) {
                ForEach(ControlSizeChoice.allCases) { Text($0.title).tag($0) }
            }
            .help("Control size")
            Toggle("Reduce Motion", isOn: $reduceMotion)
                .help("Sets the theme's motion tokens to zero")
        }
    }
}

enum ColorSchemeChoice: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum ControlSizeChoice: String, CaseIterable, Identifiable {
    case small, regular, large
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var size: ControlSize {
        switch self {
        case .small: .small
        case .regular: .regular
        case .large: .large
        }
    }
}
