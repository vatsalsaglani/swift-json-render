// Owner: jr-3 (wave 2). The one sanctioned erasure point for component styles.
public import SwiftUI

/// A type-erased view inside a style configuration (a component's content, header or
/// footer) and around a style's body.
///
/// Every component style follows `ButtonStyle`'s shape: a protocol with
/// `makeBody(configuration:)`, a configuration struct, a default style, an environment
/// entry that holds `any <Name>Style`, and a `.jr<Name>Style(_:)` modifier. The
/// configuration carries resolved props, label views, state flags and the theme; never the
/// state store, state bindings or `emit`. Erasure happens here and in the registry only.
public struct JRStyleContent: View {
    private let content: AnyView

    public init<Content: View>(_ content: Content) {
        self.content = AnyView(content)
    }

    public var body: some View { content }
}
