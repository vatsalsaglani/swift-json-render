// Owner: jr-3b. Input, Textarea, Select, Checkbox, Radio, Switch and Slider in one form.
import SwiftUI

struct FormFieldsPage: GalleryPage {
    static let title = "Form fields"
    static let group = GalleryGroup.inputs

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note:
                "Label above the field, one primary button, the focus ring visible. Checks run on blur; pattern checks never run on a keystroke."
        ) {
            SpecExample(
                "Create branch",
                json: #"""
                    {"root":"card","state":{"form":{"branch":"feature/json-render-card","base":"main","push":true,"kind":"feature","notes":"","token":""}},
                     "elements":{
                      "card":{"type":"Card","props":{"title":"New branch","maxWidth":"md"},"children":["branch","base","kind","notes","token","push","agree","depth"],"slots":{"footer":["cancel","create"]}},
                      "branch":{"type":"Input","props":{"label":"Branch name","name":"branch","placeholder":"feature/…","value":{"$bindState":"/form/branch"},
                        "checks":[{"type":"required","message":"Enter a branch name"},{"type":"pattern","args":{"pattern":"^[a-z0-9/._-]+$"},"message":"Use lower-case letters, digits, / . _ -"}]}},
                      "base":{"type":"Select","props":{"label":"Base","name":"base","options":["main","dev","release/0.22"],"value":{"$bindState":"/form/base"}}},
                      "kind":{"type":"Radio","props":{"label":"Kind","name":"kind","options":["feature","fix","chore"],"value":{"$bindState":"/form/kind"}}},
                      "notes":{"type":"Textarea","props":{"label":"Notes","name":"notes","placeholder":"Why this branch exists","rows":3,"value":{"$bindState":"/form/notes"}}},
                      "token":{"type":"Input","props":{"label":"Access token","name":"token","type":"password","placeholder":"Never stored","value":{"$bindState":"/form/token"}}},
                      "push":{"type":"Switch","props":{"label":"Push after create","name":"push","checked":{"$bindState":"/form/push"}}},
                      "agree":{"type":"Checkbox","props":{"label":"Track the remote branch","name":"track","checked":true}},
                      "depth":{"type":"Slider","props":{"label":"History depth","min":1,"max":50,"step":1,"value":20}},
                      "cancel":{"type":"Button","props":{"label":"Cancel","variant":"secondary"}},
                      "create":{"type":"Button","props":{"label":"Create branch","variant":"primary"},
                        "on":{"press":{"action":"validateForm","params":{"statePath":"/result"}}}}}}
                    """#)
            SpecExample(
                "Empty fields",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"gap":"md"},"children":["email","role"]},
                      "email":{"type":"Input","props":{"label":"Email","name":"email","type":"email","placeholder":"you@example.com"}},
                      "role":{"type":"Select","props":{"label":"Role","name":"role","options":["Engineer","Designer"],"placeholder":"Choose a role"}}}}
                    """#)
        }
    }
}
