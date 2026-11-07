// Owner: jr-3. Heading and Text examples.
import SwiftUI

struct TextPage: GalleryPage {
    static let title = "Heading and Text"
    static let group = GalleryGroup.components

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note: "One type scale: 11 / 12 / 13 / 15 / 20 / 28 pt. Three text colours only."
        ) {
            SpecExample(
                "Headings h1 to h4",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"gap":"sm"},"children":["h1","h2","h3","h4"]},
                      "h1":{"type":"Heading","props":{"text":"System status","level":"h1"}},
                      "h2":{"type":"Heading","props":{"text":"Services (h2, the default)"}},
                      "h3":{"type":"Heading","props":{"text":"API gateway","level":"h3"}},
                      "h4":{"type":"Heading","props":{"text":"Latency","level":"h4"}}}}
                    """#)
            SpecExample(
                "Text variants",
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
