// Owner: jr-3. Grid and Separator examples.
import SwiftUI

struct GridPage: GalleryPage {
    static let title = "Grid and Separator"
    static let group = GalleryGroup.components

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note: "Equal columns (1 to 6), one gap both ways. A separator is one hairline."
        ) {
            SpecExample(
                "Three columns, gap md",
                json: #"""
                    {"root":"g","state":{"plans":[{"name":"Hobby","price":"$0"},{"name":"Pro","price":"$20"},{"name":"Team","price":"$80"}]},
                     "elements":{
                      "g":{"type":"Grid","props":{"columns":3,"gap":"md"},"repeat":{"statePath":"/plans","key":"name"},"children":["c"]},
                      "c":{"type":"Card","props":{"title":{"$item":"name"}},"children":["p"]},
                      "p":{"type":"Text","props":{"text":{"$item":"price"},"variant":"lead"}}}}
                    """#)
            SpecExample(
                "Horizontal and vertical separators",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"gap":"md"},"children":["a","sep","row"]},
                      "a":{"type":"Text","props":{"text":"Above the line"}},
                      "sep":{"type":"Separator","props":{}},
                      "row":{"type":"Stack","props":{"direction":"horizontal","gap":"md","align":"center"},"children":["l","v","r"]},
                      "l":{"type":"Text","props":{"text":"Left"}},
                      "v":{"type":"Separator","props":{"orientation":"vertical"}},
                      "r":{"type":"Text","props":{"text":"Right","variant":"muted"}}}}
                    """#)
        }
    }
}
