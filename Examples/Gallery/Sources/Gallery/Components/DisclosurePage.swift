// Owner: jr-3. Accordion and Collapsible examples.
import SwiftUI

struct DisclosurePage: GalleryPage {
    static let title = "Accordion and Collapsible"
    static let group = GalleryGroup.components

    var body: some View {
        GalleryPageLayout(
            title: Self.title, note: "Hairlines only between rows. Opening is immediate."
        ) {
            SpecExample(
                "Accordion (single)",
                json: #"""
                    {"root":"a","elements":{
                      "a":{"type":"Accordion","props":{"items":[
                        {"title":"What does Degraded mean?","content":"The service still answers, but slower than normal."},
                        {"title":"How is uptime calculated?","content":"Health checks every 30 seconds over the calendar month."},
                        {"title":"How do I subscribe?","content":"Use email or a webhook on the Settings page."}]}}}}
                    """#)
            SpecExample(
                "Collapsible, open by default",
                json: #"""
                    {"root":"c","elements":{
                      "c":{"type":"Collapsible","props":{"title":"Build log","defaultOpen":true},"children":["t"]},
                      "t":{"type":"Text","props":{"text":"Compiling 412 files…","variant":"code"}}}}
                    """#)
        }
    }
}
