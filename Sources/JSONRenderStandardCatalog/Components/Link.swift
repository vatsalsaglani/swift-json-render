// Owner: jr-3b (wave 2). Link: a text link. It never opens a URL itself.
internal import Foundation
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a link style receives. `press` follows the link policy (see `JRLink`).
public struct JRLinkStyleConfiguration {
    public let label: String
    public let href: String
    /// The host name of `href`, when it has one (shown as help and read as a hint).
    public let host: String?
    public let press: @MainActor () -> Void
    public let theme: JSONRenderTheme
}

/// Restyles every Link in a subtree.
public protocol JRLinkStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRLinkStyleConfiguration) -> Body
}

/// The default link: the native link button (accent text, focus ring), with the target
/// as help text.
public struct DefaultJRLinkStyle: JRLinkStyle {
    public init() {}

    public func makeBody(configuration: JRLinkStyleConfiguration) -> some View {
        Button(configuration.label, action: configuration.press)
            .buttonStyle(.link)
            .font(configuration.theme.type.body)
            .help(configuration.href)
    }
}

extension EnvironmentValues {
    /// The link style. Default: `DefaultJRLinkStyle`.
    @Entry public var jrLinkStyle: any JRLinkStyle = DefaultJRLinkStyle()
}

extension View {
    /// Sets the style of every Link in this subtree.
    public func jrLinkStyle(_ style: some JRLinkStyle) -> some View {
        environment(\.jrLinkStyle, style)
    }
}

/// The link policy, a pure function so it is testable without views.
public enum JRLinkPolicy {
    /// What a press does.
    public enum Outcome: Equatable, Sendable {
        /// Run the element's `on.press` bindings; open nothing.
        case emit
        /// Ask the host to open the URL (`ActionHost.openURL`).
        case open(URL)
        /// Nothing (no `on.press` and no absolute URL).
        case ignore
    }

    /// When the element binds `press`, the press runs those bindings and the `href` is
    /// not opened (upstream prevents the default). Else an absolute URL with a scheme
    /// goes to the host, which decides whether to open it. A relative or `#` link does
    /// nothing.
    public static func outcome(href: String, bindsPress: Bool) -> Outcome {
        if bindsPress { return .emit }
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty else {
            return .ignore
        }
        return .open(url)
    }
}

/// `Link`: upstream shadcn props. A press emits `press` when the spec binds it; otherwise
/// the URL goes to the host's `openURL` (through `\.jrURLOpener`). The component never
/// opens a URL itself.
@JRComponent(
    "Link", description: "Anchor link. Bind on.press for click handler.", events: ["press"])
public struct JRLink: View {
    @JRProp var label: String
    @JRProp var href: String

    @Environment(\.jrLinkStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrElementEvents) private var events
    @Environment(\.jrURLOpener) private var openURL

    public var body: some View {
        let context = jrContext
        let outcome = JRLinkPolicy.outcome(href: href, bindsPress: events.contains("press"))
        let opener = openURL
        let host = URL(string: href)?.host()
        let configuration = JRLinkStyleConfiguration(
            label: label.isEmpty ? href : label, href: href, host: host,
            press: {
                switch outcome {
                case .emit: context.emit("press", [:])
                case .open(let url): opener(url)
                case .ignore: break
                }
            },
            theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .accessibilityAddTraits(.isLink)
            .accessibilityHint(Text(host.map { "Opens \($0)" } ?? ""))
    }
}
