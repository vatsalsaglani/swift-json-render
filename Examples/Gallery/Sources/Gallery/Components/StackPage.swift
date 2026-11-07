// Owner: jr-3. Stack examples.
import SwiftUI

struct StackPage: GalleryPage {
    static let title = "Stack"
    static let group = GalleryGroup.components

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note:
                "Gaps none 0, sm 6, md 10, lg 16, xl 20. Horizontal stacks wrap; justify spreads free space."
        ) {
            SpecExample(
                "Vertical, gap md",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"gap":"md"},"children":["a","b","c"]},
                      "a":{"type":"Text","props":{"text":"First line"}},
                      "b":{"type":"Text","props":{"text":"Second line"}},
                      "c":{"type":"Text","props":{"text":"Third line","variant":"muted"}}}}
                    """#)
            SpecExample(
                "Horizontal, justify between",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"direction":"horizontal","justify":"between","align":"center"},"children":["a","b"]},
                      "a":{"type":"Text","props":{"text":"Left"}},
                      "b":{"type":"Text","props":{"text":"Right","variant":"muted"}}}}
                    """#)
            SpecExample(
                "Horizontal, wrapping, gap sm",
                json: #"""
                    {"root":"s","state":{"tags":["swift","json-render","native","streaming","themes","accessibility","charts","macOS","layers"]},"elements":{
                      "s":{"type":"Stack","props":{"direction":"horizontal","gap":"sm"},"repeat":{"statePath":"/tags"},"children":["t"]},
                      "t":{"type":"Text","props":{"text":{"$item":""},"variant":"code"}}}}
                    """#)
        }
    }
}
