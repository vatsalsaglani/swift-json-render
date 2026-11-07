// Owner: jr-1b (wave 1).
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct JSONRenderMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [JRComponentMacro.self, JRPropMacro.self]
}
