// Owner: jr-3b. Button, Link, Toggle, ToggleGroup and ButtonGroup.
import SwiftUI

struct ButtonsPage: GalleryPage {
    static let title = "Buttons and toggles"
    static let group = GalleryGroup.inputs

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note:
                "The accent marks the one primary action, which also takes Return. Links open only through the host."
        ) {
            SpecExample(
                "Button variants",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"direction":"horizontal","gap":"sm","align":"center"},"children":["p","s2","d","pl","i","x"]},
                      "p":{"type":"Button","props":{"label":"Re-run suite","variant":"primary"}},
                      "s2":{"type":"Button","props":{"label":"Open file"}},
                      "d":{"type":"Button","props":{"label":"Delete branch","variant":"danger"}},
                      "pl":{"type":"Button","props":{"label":"Details","variant":"plain"}},
                      "i":{"type":"Button","props":{"label":"Share","icon":"square.and.arrow.up"}},
                      "x":{"type":"Button","props":{"label":"Merge","disabled":true}}}}
                    """#)
            SpecExample(
                "Sizes and a link",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"direction":"horizontal","gap":"sm","align":"center"},"children":["sm","md","lg","l"]},
                      "sm":{"type":"Button","props":{"label":"Small","size":"sm"}},
                      "md":{"type":"Button","props":{"label":"Regular"}},
                      "lg":{"type":"Button","props":{"label":"Large","size":"lg"}},
                      "l":{"type":"Link","props":{"label":"Read the release notes","href":"https://example.com/notes"}}}}
                    """#)
            SpecExample(
                "Toggles",
                json: #"""
                    {"root":"s","state":{"view":"list","fmt":"bold,italic","wrap":true},"elements":{
                      "s":{"type":"Stack","props":{"gap":"md"},"children":["row","row2"]},
                      "row":{"type":"Stack","props":{"direction":"horizontal","gap":"md","align":"center"},"children":["t","bg"]},
                      "row2":{"type":"Stack","props":{"direction":"horizontal","gap":"md","align":"center"},"children":["tg1","tg2"]},
                      "t":{"type":"Toggle","props":{"label":"Wrap lines","pressed":{"$bindState":"/wrap"}}},
                      "bg":{"type":"ButtonGroup","props":{"buttons":[{"label":"List","value":"list"},{"label":"Grid","value":"grid"},{"label":"Columns","value":"cols"}],"selected":{"$bindState":"/view"}}},
                      "tg1":{"type":"ToggleGroup","props":{"items":[{"label":"Day","value":"d"},{"label":"Week","value":"w"},{"label":"Month","value":"m"}],"value":"w"}},
                      "tg2":{"type":"ToggleGroup","props":{"type":"multiple","items":[{"label":"Bold","value":"bold"},{"label":"Italic","value":"italic"},{"label":"Underline","value":"under"}],"value":{"$bindState":"/fmt"}}}}}
                    """#)
        }
    }
}
