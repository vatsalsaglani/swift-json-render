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

    /// Definition and renderer per component. Components with object-list props then
    /// replace their definition with the spelled-out schema.
    static func registerGroup1(into catalog: inout Catalog) throws(CatalogError) {
        try catalog.register(JRCard.self)
        try catalog.register(JRStack.self)
        try catalog.register(JRGrid.self)
        try catalog.register(JRSeparator.self)
        try catalog.register(JRTabs.self)
        try catalog.replaceDefinition(JRTabs.catalogDefinition)
        try catalog.register(JRAccordion.self)
        try catalog.replaceDefinition(JRAccordion.catalogDefinition)
        try catalog.register(JRCollapsible.self)
        try catalog.register(JRPagination.self)
        try catalog.register(JRDialog.self)
        try catalog.register(JRDrawer.self)
        try catalog.register(JRTooltip.self)
        try catalog.register(JRPopover.self)
        try catalog.register(JRDropdownMenu.self)
        try catalog.replaceDefinition(JRDropdownMenu.catalogDefinition)
        try catalog.register(JRHeading.self)
        try catalog.register(JRText.self)
        try catalog.register(JRBadge.self)
        try catalog.register(JRAlert.self)
        try catalog.register(JRSkeleton.self)
    }
}
