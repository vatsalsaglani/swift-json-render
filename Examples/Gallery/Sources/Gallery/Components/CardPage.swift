// Owner: jr-3. Card examples.
import SwiftUI

struct CardPage: GalleryPage {
    static let title = "Card"
    static let group = GalleryGroup.components

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note:
                "A surface with a title, a description, content and footer actions. Variants: outlined, plain, elevated."
        ) {
            SpecExample(
                "Outlined (default) with a footer slot",
                json: #"""
                    {"root":"card","elements":{
                      "card":{"type":"Card","props":{"title":"Build 4213","description":"main · 2 min ago · 1m 48s"},
                        "children":["text","badges"],"slots":{"footer":["open"]}},
                      "text":{"type":"Text","props":{"text":"Compiled 412 files. 3 warnings in CanvasBoardState.swift."}},
                      "badges":{"type":"Stack","props":{"direction":"horizontal","gap":"sm"},"children":["b1","b2"]},
                      "b1":{"type":"Text","props":{"text":"Passed","variant":"caption"}},
                      "b2":{"type":"Text","props":{"text":"Release","variant":"caption"}},
                      "open":{"type":"Text","props":{"text":"Open log","variant":"muted"}}}}
                    """#)
            SpecExample(
                "Elevated, medium width",
                json: #"""
                    {"root":"card","elements":{
                      "card":{"type":"Card","props":{"title":"Overview","description":"Your account summary","maxWidth":"md","variant":"elevated"},"children":["t"]},
                      "t":{"type":"Text","props":{"text":"One shadow, radius 8, y 2. A card inside a card draws none."}}}}
                    """#)
            SpecExample(
                "Plain: space groups the content",
                json: #"""
                    {"root":"card","elements":{
                      "card":{"type":"Card","props":{"title":"Notes","variant":"plain"},"children":["t"]},
                      "t":{"type":"Text","props":{"text":"No surface, no hairline, no padding.","variant":"muted"}}}}
                    """#)
        }
    }
}
