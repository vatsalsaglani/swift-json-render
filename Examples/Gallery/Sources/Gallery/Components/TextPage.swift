// Owner: jr-3. Text examples.
import SwiftUI

struct TextPage: GalleryPage {
    static let title = "Text"
    static let group = GalleryGroup.components

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note: "One type scale: 11 / 12 / 13 / 15 pt. Three text colours only."
        ) {
            SpecExample(
                "Variants",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"gap":"md"},"children":["lead","body","muted","caption","code"]},
                      "lead":{"type":"Text","props":{"text":"Lead: an introduction in 15 pt regular.","variant":"lead"}},
                      "body":{"type":"Text","props":{"text":"Body: 13 pt, the primary text colour. It wraps across lines when the text is longer than the column, and it stays selectable."}},
                      "muted":{"type":"Text","props":{"text":"Muted: 12 pt secondary text.","variant":"muted"}},
                      "caption":{"type":"Text","props":{"text":"Caption: 11 pt secondary text.","variant":"caption"}},
                      "code":{"type":"Text","props":{"text":"swift build --package-path Examples/Gallery","variant":"code"}}}}
                    """#)
        }
    }
}
