import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI

/// One scripted interaction step: a direct store write (a user typing into a bound
/// field), an emitted event, or a wait for watcher results.
enum ScriptStep: Sendable {
    case write(JSONPointer, JSONValue)
    case emit(String, String)
    case waitFor(JSONPointer, JSONValue)
}

/// The scripted interactions per upstream example spec.
enum Scripts {
    /// Watchers run only on drawn elements, so the cascading script waits for watcher
    /// results only when `Select` (jr-3b's group 2) is registered.
    static func steps(for fixture: String, catalog: Catalog) -> [ScriptStep] {
        if fixture == "cascading-selects", catalog.component(named: "Select") == nil {
            return [.write("/form/country", "UK"), .write("/form/city", "London")]
        }
        let steps: [ScriptStep] =
            switch fixture {
            case "confetti":
                [.emit("btn", "press"), .emit("btn", "press")]
            case "settings-form":
                [
                    .write("/name", "Grace Hopper"), .write("/notifications", false),
                    .write("/role", "Designer"), .emit("saveBtn", "press"),
                ]
            case "registration-form":
                [
                    .emit("submitBtn", "press"), .write("/form/name", "Ada"),
                    .write("/form/email", "ada@example.com"),
                    .write("/form/accountType", "business"),
                    .emit("submitBtn", "press"),
                ]
            case "cascading-selects":
                [
                    .write("/form/country", "UK"),
                    .waitFor("/availableCities", ["London", "Leeds"]),
                    .write("/form/city", "London"), .write("/form/country", "Japan"),
                    .waitFor("/availableCities", ["Tokyo", "Osaka"]), .waitFor("/form/city", ""),
                ]
            default:
                [.write("/scratch", 1), .write("/scratch", 2)]
            }
        return steps
    }

    /// `Catalog.standard` plus the two `$computed` functions the cascading example needs.
    static func catalog() throws -> Catalog {
        var catalog = try Catalog.standard
        catalog.function("citiesForCountry") { args in
            let cities: [String: [String]] = [
                "UK": ["London", "Leeds"], "Japan": ["Tokyo", "Osaka"],
            ]
            let country = (args["country"] ?? nil)?.stringValue ?? ""
            return .array((cities[country] ?? []).map(JSONValue.string))
        }
        catalog.function("formatAddress") { args in
            let city = (args["city"] ?? nil)?.stringValue ?? ""
            let country = (args["country"] ?? nil)?.stringValue ?? ""
            return .string([city, country].filter { !$0.isEmpty }.joined(separator: ", "))
        }
        return catalog
    }
}
