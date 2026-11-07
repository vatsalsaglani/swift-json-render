// Owner: jr-3 (Gallery shell). Headless PNG snapshots of every page.
import AppKit
import JSONRenderSwiftUI
import SwiftUI

/// Renders every page × {native, highContrast} × {light, dark} into an offscreen
/// `NSWindow` + `NSHostingView` and writes `<group>-<page>-<preset>-<scheme>.png`.
///
/// Not `ImageRenderer`: it skips AppKit-backed controls such as `Table`. No window is
/// shown; the activation policy is `.prohibited`.
@MainActor
enum Snapshotter {
    static let width: CGFloat = 720

    static func run(directory: String) -> Int32 {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            FileHandle.standardError.write(Data("Cannot create \(directory)\n".utf8))
            return 1
        }
        var written = 0
        for page in GalleryPages.all {
            for preset in GalleryPreset.allCases {
                for dark in [false, true] {
                    let name = [
                        page.group.rawValue, slug(page.title), preset.rawValue,
                        dark ? "dark" : "light",
                    ].joined(separator: "-")
                    let view = AnyView(page.init())
                        .jsonRenderTheme(preset.theme)
                        .environment(\.gallerySnapshotMode, true)
                        .environment(\.colorScheme, dark ? .dark : .light)
                        .frame(width: width)
                        .background(Color(nsColor: .windowBackgroundColor))
                    guard let png = render(view, dark: dark) else {
                        FileHandle.standardError.write(Data("Cannot render \(name)\n".utf8))
                        return 1
                    }
                    do {
                        try png.write(to: folder.appendingPathComponent(name + ".png"))
                        written += 1
                    } catch {
                        FileHandle.standardError.write(Data("Cannot write \(name)\n".utf8))
                        return 1
                    }
                }
            }
        }
        print("Wrote \(written) snapshots to \(folder.path)")
        return 0
    }

    static func render(_ view: some View, dark: Bool) -> Data? {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 480), styleMask: [.borderless],
            backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        // Let onAppear and tasks run (the render model is created on appear).
        for _ in 0..<3 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        let height = min(max(host.fittingSize.height, 120), 3000)
        window.setContentSize(NSSize(width: width, height: height))
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])
    }

    static func slug(_ title: String) -> String {
        title.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { result, character in
                if character == "-", result.last == "-" { return }
                result.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
