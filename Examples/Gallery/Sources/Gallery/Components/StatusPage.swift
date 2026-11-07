// Owner: jr-3. Badge, Alert and Skeleton examples.
import SwiftUI

struct StatusPage: GalleryPage {
    static let title = "Badge, Alert and Skeleton"
    static let group = GalleryGroup.components

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note: "Status is a symbol, a word and a hue together. Placeholders are static."
        ) {
            SpecExample(
                "Badges",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"direction":"horizontal","gap":"sm"},"children":["a","b","c","d","e","f"]},
                      "a":{"type":"Badge","props":{"text":"Release"}},
                      "b":{"type":"Badge","props":{"text":"Draft","variant":"secondary"}},
                      "c":{"type":"Badge","props":{"text":"v0.22","variant":"outline"}},
                      "d":{"type":"Badge","props":{"text":"Passed","variant":"good"}},
                      "e":{"type":"Badge","props":{"text":"Slow","variant":"warning"}},
                      "f":{"type":"Badge","props":{"text":"Failed","variant":"destructive"}}}}
                    """#)
            SpecExample(
                "Alerts",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"gap":"sm","align":"stretch"},"children":["w","g","e","i"]},
                      "w":{"type":"Alert","props":{"title":"3 warnings","message":"Unused variable in CanvasBoardState.swift:212","type":"warning"}},
                      "g":{"type":"Alert","props":{"title":"Saved","message":"Ensemble \"Voice\" written at 16:42","type":"success"}},
                      "e":{"type":"Alert","props":{"title":"Build failed","message":"error: cannot find type 'SpecStore' in scope","type":"error"}},
                      "i":{"type":"Alert","props":{"title":"Heads up","message":"The index rebuilds after the next launch."}}}}
                    """#)
            SpecExample(
                "Skeletons",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"gap":"md"},"children":["l","row","card"]},
                      "l":{"type":"Skeleton","props":{"width":"60%","height":"14px"}},
                      "row":{"type":"Stack","props":{"direction":"horizontal","gap":"md","align":"center"},"children":["c","t"]},
                      "c":{"type":"Skeleton","props":{"width":"32px","height":"32px","rounded":true,"shape":"circle"}},
                      "t":{"type":"Skeleton","props":{"width":"180px","height":"12px"}},
                      "card":{"type":"Skeleton","props":{"shape":"card"}}}}
                    """#)
        }
    }
}
