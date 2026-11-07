// Owner: jr-3b. Progress and Spinner.
import SwiftUI

struct FeedbackPage: GalleryPage {
    static let title = "Progress and Spinner"
    static let group = GalleryGroup.inputs

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note:
                "Progress shows a tabular percentage. Under Reduce Motion the spinner becomes a still symbol."
        ) {
            SpecExample(
                "Progress",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"gap":"md"},"children":["a","b","c"]},
                      "a":{"type":"Progress","props":{"value":72,"max":100,"label":"Profile completion"}},
                      "b":{"type":"Progress","props":{"value":3,"max":8,"label":"Suites passed"}},
                      "c":{"type":"Progress","props":{"value":100}}}}
                    """#)
            SpecExample(
                "Spinners",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"direction":"horizontal","gap":"lg","align":"center"},"children":["a","b","c"]},
                      "a":{"type":"Spinner","props":{"size":"sm","label":"Indexing"}},
                      "b":{"type":"Spinner","props":{"label":"Running tests"}},
                      "c":{"type":"Spinner","props":{"size":"lg"}}}}
                    """#)
        }
    }
}
