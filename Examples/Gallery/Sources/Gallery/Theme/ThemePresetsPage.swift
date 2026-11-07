// Owner: jr-3. The same spec in both presets, and the token layers.
import JSONRenderSwiftUI
import SwiftUI

struct ThemePresetsPage: GalleryPage {
    static let title = "Presets and layers"
    static let group = GalleryGroup.theme

    static let spec = #"""
        {"root":"card","elements":{
          "card":{"type":"Card","props":{"title":"Failing tests by suite","description":"Last run 41 s ago"},"children":["s"]},
          "s":{"type":"Stack","props":{"gap":"sm"},"children":["a","b"]},
          "a":{"type":"Text","props":{"text":"CanvasBoardStateTests: 4 failing"}},
          "b":{"type":"Text","props":{"text":"VoiceSessionTests: 2 failing","variant":"muted"}}}}
        """#

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note: "Layer a: a whole preset, one token, or one type. Semantics never change."
        ) {
            SpecExample("Native preset", json: Self.spec)
                .jsonRenderTheme(.native)
            SpecExample("High contrast preset", json: Self.spec)
                .jsonRenderTheme(.highContrast)
            SpecExample("One token: card radius 4", json: Self.spec)
                .jsonRenderTheme(\.radius.card, 4)
            SpecExample("Per type: high contrast for Text only", json: Self.spec)
                .jsonRenderTheme(.highContrast, forTypes: ["Text"])
        }
    }
}
