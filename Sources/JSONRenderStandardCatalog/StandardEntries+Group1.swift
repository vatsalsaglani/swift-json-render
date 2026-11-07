// Owner: jr-3 (wave 2); seeded empty by jr-1b. Append one line per component.
internal import JSONRenderCore
internal import JSONRenderSwiftUI

extension StandardEntries {
    /// jr-3's 18 components, in the brief's table order.
    static let group1: [ComponentDefinition] = [
        JRCard.definition,
        JRStack.definition,
        JRGrid.definition,
        JRSeparator.definition,
        JRTabs.catalogDefinition,
        JRAccordion.catalogDefinition,
        JRCollapsible.definition,
        JRPagination.definition,
        JRDialog.definition,
        JRDrawer.definition,
        JRTooltip.definition,
        JRPopover.definition,
        JRDropdownMenu.catalogDefinition,
        JRHeading.definition,
        JRText.definition,
        JRBadge.definition,
        JRAlert.definition,
        JRSkeleton.definition,
    ]

    /// `register(view:)`, never `register(X.self)` (that stores no renderer). Components
    /// with object-list props then replace their definition with the spelled-out schema.
    static func registerGroup1(into catalog: inout Catalog) throws(CatalogError) {
        try catalog.register(view: JRCard.self)
        try catalog.register(view: JRStack.self)
        try catalog.register(view: JRGrid.self)
        try catalog.register(view: JRSeparator.self)
        try catalog.register(view: JRTabs.self)
        try catalog.replaceDefinition(JRTabs.catalogDefinition)
        try catalog.register(view: JRAccordion.self)
        try catalog.replaceDefinition(JRAccordion.catalogDefinition)
        try catalog.register(view: JRCollapsible.self)
        try catalog.register(view: JRPagination.self)
        try catalog.register(view: JRDialog.self)
        try catalog.register(view: JRDrawer.self)
        try catalog.register(view: JRTooltip.self)
        try catalog.register(view: JRPopover.self)
        try catalog.register(view: JRDropdownMenu.self)
        try catalog.replaceDefinition(JRDropdownMenu.catalogDefinition)
        try catalog.register(view: JRHeading.self)
        try catalog.register(view: JRText.self)
        try catalog.register(view: JRBadge.self)
        try catalog.register(view: JRAlert.self)
        try catalog.register(view: JRSkeleton.self)
    }
}
