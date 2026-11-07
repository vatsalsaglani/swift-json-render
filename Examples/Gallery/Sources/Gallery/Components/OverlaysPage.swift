// Owner: jr-3. Dialog, Drawer, Tooltip, Popover and DropdownMenu examples.
import JSONRenderSwiftUI
import SwiftUI

struct OverlaysPage: GalleryPage {
    static let title = "Dialog and menus"
    static let group = GalleryGroup.components

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note:
                "Dialog and Drawer open from state (openPath). Shown inline here; in a window they are sheets."
        ) {
            SpecExample(
                "Dialog content (inline preview, open)",
                json: #"""
                    {"root":"d","state":{"ui":{"confirm":true}},"elements":{
                      "d":{"type":"Dialog","props":{"title":"Delete branch?","description":"feature/json-render-card will be removed.","openPath":"/ui/confirm"},
                        "children":["t"],"slots":{"footer":["note"]}},
                      "t":{"type":"Text","props":{"text":"The branch has 3 commits that are not on main."}},
                      "note":{"type":"Text","props":{"text":"Footer slot","variant":"caption"}}}}
                    """#
            )
            .environment(\.jrInsidePresentation, true)
            SpecExample(
                "Tooltip, Popover and DropdownMenu",
                json: #"""
                    {"root":"s","state":{"sort":"name"},"elements":{
                      "s":{"type":"Stack","props":{"direction":"horizontal","gap":"lg","align":"center"},"children":["tip","pop","menu"]},
                      "tip":{"type":"Tooltip","props":{"content":"p95 over the last 7 runs","text":"Wall time"}},
                      "pop":{"type":"Popover","props":{"trigger":"Details","content":"Compiled 412 files in 1m 48s."}},
                      "menu":{"type":"DropdownMenu","props":{"label":"Sort by","items":[{"label":"Name","value":"name"},{"label":"Duration","value":"duration"}],"value":{"$bindState":"/sort"}}}}}
                    """#)
        }
    }
}
