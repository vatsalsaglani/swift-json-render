// Owner: jr-3. Tabs and Pagination examples.
import SwiftUI

struct TabsPage: GalleryPage {
    static let title = "Tabs and Pagination"
    static let group = GalleryGroup.components

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note:
                "Underline only, no pill chrome; the accent marks the active tab. Children show by `visible`."
        ) {
            SpecExample(
                "Bound tabs drive visible conditions",
                json: #"""
                    {"root":"card","state":{"tab":"failures"},"elements":{
                      "card":{"type":"Card","props":{},"children":["tabs"]},
                      "tabs":{"type":"Tabs","props":{"tabs":[{"label":"Failures","value":"failures"},{"label":"Slowest","value":"slowest"},{"label":"Flaky","value":"flaky"}],"value":{"$bindState":"/tab"}},
                        "children":["f","s"]},
                      "f":{"type":"Text","props":{"text":"4 failures in CanvasBoardStateTests"},"visible":{"$state":"/tab","eq":"failures"}},
                      "s":{"type":"Text","props":{"text":"Slowest: VoiceSessionTests, 12 s"},"visible":{"$state":"/tab","eq":"slowest"}}}}
                    """#)
            SpecExample(
                "Segmented variant",
                json: #"""
                    {"root":"tabs","elements":{
                      "tabs":{"type":"Tabs","props":{"tabs":[{"label":"Day","value":"d"},{"label":"Week","value":"w"},{"label":"Month","value":"m"}],"defaultValue":"w","variant":"segmented"}}}}
                    """#)
            SpecExample(
                "Pagination bound to /page",
                json: #"""
                    {"root":"p","state":{"page":3},"elements":{
                      "p":{"type":"Pagination","props":{"totalPages":12,"page":{"$bindState":"/page"}}}}}
                    """#)
        }
    }
}
