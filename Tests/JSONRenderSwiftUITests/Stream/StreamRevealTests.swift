import SwiftUI
import Testing

@testable import JSONRenderSwiftUI

@MainActor
@Suite("Stream reveal")
struct StreamRevealTests {
    @Test("Reduce Motion: no fade, visible from the first frame")
    func reduceMotion() {
        #expect(
            StreamRevealModifier.animation(reduceMotion: true, duration: .milliseconds(180)) == nil)
        #expect(StreamRevealModifier.startsHidden(reduceMotion: true) == false)
    }

    @Test("Default: a fade over the theme's reveal duration")
    func fade() {
        #expect(
            StreamRevealModifier.animation(reduceMotion: false, duration: .milliseconds(180)) != nil
        )
        #expect(StreamRevealModifier.animation(reduceMotion: false, duration: .zero) == nil)
        #expect(StreamRevealModifier.startsHidden(reduceMotion: false))
        #expect(JSONRenderTheme.native.motion.reveal == .milliseconds(180))
    }
}
