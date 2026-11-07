// Owner: jr-3b. Table from inline rows and from a repeat with row buttons.
import SwiftUI

struct TablePage: GalleryPage {
    static let title = "Table"
    static let group = GalleryGroup.inputs

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note:
                "Hairline rows, no stripes, number columns right-aligned with tabular digits. Repeat rows keep their own scope."
        ) {
            SpecExample(
                "Inline rows (sortable)",
                json: #"""
                    {"root":"t","elements":{
                      "t":{"type":"Table","props":{"columns":["Suite","Failed","Total"],"sortable":true,
                        "rows":[["CanvasBoardStateTests","4","61"],["VoiceSessionTests","2","38"],["MDXBlockScannerTests","1","27"]],
                        "caption":"Failing suites in build 4213"}}}}
                    """#)
            SpecExample(
                "Repeat rows with actions",
                json: #"""
                    {"root":"t","state":{"files":[
                        {"path":"Sources/JSONRenderCore/Stream/SpecStore.swift","added":212,"removed":0},
                        {"path":"Sources/JSONRenderSwiftUI/FrameCoalescer.swift","added":96,"removed":4},
                        {"path":"Tests/ParityFixtures/streams/status.jsonl","added":48,"removed":0}]},
                     "elements":{
                      "t":{"type":"Table","props":{"columns":[{"key":"path","label":"File"},{"key":"added","label":"+"},{"key":"removed","label":"−"}],"rows":[]},
                           "repeat":{"statePath":"/files","key":"path"},"children":["open","remove"]},
                      "open":{"type":"Button","props":{"label":"Open","size":"sm"}},
                      "remove":{"type":"Button","props":{"label":"Remove","size":"sm","variant":"plain"},
                        "on":{"press":{"action":"removeState","params":{"statePath":"/files","index":{"$index":true}}}}}}}
                    """#)
            SpecExample(
                "Empty",
                json: #"""
                    {"root":"t","elements":{
                      "t":{"type":"Table","props":{"columns":["Name","Status"],"rows":[]},"slots":{"empty":["none"]}},
                      "none":{"type":"Text","props":{"text":"No failing tests.","variant":"muted"}}}}
                    """#)
        }
    }
}
