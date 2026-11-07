// Owner: jr-2 (wave 2).
public import SwiftUI

extension View {
    /// Fades the view in on its first appearance, over `theme.motion.reveal` (180 ms in the
    /// native theme). Instant when Reduce Motion is on. The renderer applies it where a
    /// skeleton becomes content.
    public func jrStreamReveal() -> some View {
        modifier(StreamRevealModifier())
    }
}

/// The modifier behind `jrStreamReveal()`.
public struct StreamRevealModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.jsonRenderTheme) private var theme
    @State private var revealed = false

    public init() {}

    public func body(content: Content) -> some View {
        content
            .opacity(
                StreamRevealModifier.startsHidden(reduceMotion: reduceMotion) && !revealed ? 0 : 1
            )
            .onAppear {
                guard !revealed else { return }
                if let animation = StreamRevealModifier.animation(
                    reduceMotion: reduceMotion, duration: theme.motion.reveal)
                {
                    withAnimation(animation) { revealed = true }
                } else {
                    revealed = true
                }
            }
    }

    /// `false` under Reduce Motion: the view is visible from its first frame.
    public static func startsHidden(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    /// The fade, or `nil` (no animation) under Reduce Motion or for a zero duration.
    public static func animation(reduceMotion: Bool, duration: Duration) -> Animation? {
        guard !reduceMotion, duration > .zero else { return nil }
        let components = duration.components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return .easeOut(duration: seconds)
    }
}
