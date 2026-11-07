// Owner: jr-3b (wave 2); seeded empty by jr-1b. Append one line per component.
internal import JSONRenderCore
internal import JSONRenderSwiftUI

extension StandardEntries {
    /// jr-3b's 18 input and data components, in the brief's table order.
    static let group2: [ComponentDefinition] = [
        JRImage.definition,
        JRAvatar.definition,
        JRCarousel.catalogDefinition,
        JRTable.catalogDefinition,
        JRProgress.definition,
        JRSpinner.definition,
        JRButton.definition,
        JRLink.definition,
        JRInput.catalogDefinition,
        JRTextarea.catalogDefinition,
        JRSelect.catalogDefinition,
        JRCheckbox.catalogDefinition,
        JRRadio.catalogDefinition,
        JRSwitch.catalogDefinition,
        JRSlider.definition,
        JRToggle.definition,
        JRToggleGroup.catalogDefinition,
        JRButtonGroup.catalogDefinition,
    ]

    /// Definition and renderer per component. Components with object-list props then
    /// replace their definition with the spelled-out schema.
    static func registerGroup2(into catalog: inout Catalog) throws(CatalogError) {
        try catalog.register(JRImage.self)
        try catalog.register(JRAvatar.self)
        try catalog.register(JRCarousel.self)
        try catalog.replaceDefinition(JRCarousel.catalogDefinition)
        try catalog.register(JRTable.self)
        try catalog.replaceDefinition(JRTable.catalogDefinition)
        try catalog.register(JRProgress.self)
        try catalog.register(JRSpinner.self)
        try catalog.register(JRButton.self)
        try catalog.register(JRLink.self)
        try catalog.register(JRInput.self)
        try catalog.replaceDefinition(JRInput.catalogDefinition)
        try catalog.register(JRTextarea.self)
        try catalog.replaceDefinition(JRTextarea.catalogDefinition)
        try catalog.register(JRSelect.self)
        try catalog.replaceDefinition(JRSelect.catalogDefinition)
        try catalog.register(JRCheckbox.self)
        try catalog.replaceDefinition(JRCheckbox.catalogDefinition)
        try catalog.register(JRRadio.self)
        try catalog.replaceDefinition(JRRadio.catalogDefinition)
        try catalog.register(JRSwitch.self)
        try catalog.replaceDefinition(JRSwitch.catalogDefinition)
        try catalog.register(JRSlider.self)
        try catalog.register(JRToggle.self)
        try catalog.register(JRToggleGroup.self)
        try catalog.replaceDefinition(JRToggleGroup.catalogDefinition)
        try catalog.register(JRButtonGroup.self)
        try catalog.replaceDefinition(JRButtonGroup.catalogDefinition)
    }
}
