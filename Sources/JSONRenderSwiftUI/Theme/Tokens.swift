// Owner: jr-1b (wave 1). Frozen shape: wave 2 adds values in Theme/Presets/, never fields here.
public import SwiftUI

/// The design tokens every json-render view reads. Presets live in `Theme/Presets/`; the
/// environment key is `EnvironmentValues.jsonRenderTheme`.
public struct JSONRenderTheme: Sendable, Equatable {
    public var color: ColorRoles
    public var type: TypeScale
    public var space: SpaceScale
    public var radius: RadiusScale
    public var elevation: Elevation
    public var motion: Motion
    public var charts: ChartTokens

    public init(
        color: ColorRoles, type: TypeScale, space: SpaceScale, radius: RadiusScale,
        elevation: Elevation, motion: Motion, charts: ChartTokens
    ) {
        self.color = color
        self.type = type
        self.space = space
        self.radius = radius
        self.elevation = elevation
        self.motion = motion
        self.charts = charts
    }
}

/// Semantic colour roles.
public struct ColorRoles: Sendable, Equatable {
    public var surface: Color
    public var surfaceRaised: Color
    public var text: Color
    public var textSecondary: Color
    public var textMuted: Color
    public var hairline: Color
    public var accent: Color
    public var onAccent: Color
    public var good: Color
    public var warning: Color
    public var critical: Color
    public var info: Color
    public var focus: Color

    public init(
        surface: Color, surfaceRaised: Color, text: Color, textSecondary: Color,
        textMuted: Color, hairline: Color, accent: Color, onAccent: Color, good: Color,
        warning: Color, critical: Color, info: Color, focus: Color
    ) {
        self.surface = surface
        self.surfaceRaised = surfaceRaised
        self.text = text
        self.textSecondary = textSecondary
        self.textMuted = textMuted
        self.hairline = hairline
        self.accent = accent
        self.onAccent = onAccent
        self.good = good
        self.warning = warning
        self.critical = critical
        self.info = info
        self.focus = focus
    }
}

/// The type ramp.
public struct TypeScale: Sendable, Equatable {
    public struct Weights: Sendable, Equatable {
        public var regular: Font.Weight
        public var medium: Font.Weight
        public var semibold: Font.Weight

        public init(regular: Font.Weight, medium: Font.Weight, semibold: Font.Weight) {
            self.regular = regular
            self.medium = medium
            self.semibold = semibold
        }
    }

    public var caption: Font
    public var footnote: Font
    public var body: Font
    public var bodyEmphasis: Font
    public var title: Font
    public var display: Font
    public var mono: Font
    public var weights: Weights

    public init(
        caption: Font, footnote: Font, body: Font, bodyEmphasis: Font, title: Font,
        display: Font, mono: Font, weights: Weights
    ) {
        self.caption = caption
        self.footnote = footnote
        self.body = body
        self.bodyEmphasis = bodyEmphasis
        self.title = title
        self.display = display
        self.mono = mono
        self.weights = weights
    }
}

/// Spacing steps, smallest first.
public struct SpaceScale: Sendable, Equatable {
    public var s1: CGFloat
    public var s2: CGFloat
    public var s3: CGFloat
    public var s4: CGFloat
    public var s5: CGFloat
    public var s6: CGFloat

    public init(s1: CGFloat, s2: CGFloat, s3: CGFloat, s4: CGFloat, s5: CGFloat, s6: CGFloat) {
        self.s1 = s1
        self.s2 = s2
        self.s3 = s3
        self.s4 = s4
        self.s5 = s5
        self.s6 = s6
    }
}

/// Corner radii.
public struct RadiusScale: Sendable, Equatable {
    public var control: CGFloat
    public var field: CGFloat
    public var card: CGFloat

    public init(control: CGFloat, field: CGFloat, card: CGFloat) {
        self.control = control
        self.field = field
        self.card = card
    }
}

/// The card shadow.
public struct Elevation: Sendable, Equatable {
    public var cardShadowRadius: CGFloat
    public var cardShadowY: CGFloat
    public var cardShadowOpacity: Double

    public init(cardShadowRadius: CGFloat, cardShadowY: CGFloat, cardShadowOpacity: Double) {
        self.cardShadowRadius = cardShadowRadius
        self.cardShadowY = cardShadowY
        self.cardShadowOpacity = cardShadowOpacity
    }
}

/// Animation durations. Views skip motion when Reduce Motion is on.
public struct Motion: Sendable, Equatable {
    public var reveal: Duration
    public var pulse: Duration

    public init(reveal: Duration, pulse: Duration) {
        self.reveal = reveal
        self.pulse = pulse
    }
}

/// Chart tokens. The default values (`ChartTokens.standard`, palettes included) live in
/// `Theme/Presets/ChartTokens+Defaults.swift`, so every preset carries them. `JSONRenderCharts`
/// adds chart-specific values only.
public struct ChartTokens: Sendable, Equatable {
    /// Eight categorical series colours.
    public var categorical: [Color]
    /// A light-to-dark ramp for magnitudes.
    public var sequential: [Color]
    /// A negative-neutral-positive ramp.
    public var diverging: [Color]
    public var gridline: Color
    public var axisFont: Font
    public var barCornerRadius: CGFloat
    public var lineWidth: CGFloat
    public var pointSize: CGFloat
    public var gaugeTrackWidth: CGFloat
    public var sliceGap: CGFloat

    public init(
        categorical: [Color], sequential: [Color], diverging: [Color], gridline: Color,
        axisFont: Font, barCornerRadius: CGFloat, lineWidth: CGFloat, pointSize: CGFloat,
        gaugeTrackWidth: CGFloat, sliceGap: CGFloat
    ) {
        self.categorical = categorical
        self.sequential = sequential
        self.diverging = diverging
        self.gridline = gridline
        self.axisFont = axisFont
        self.barCornerRadius = barCornerRadius
        self.lineWidth = lineWidth
        self.pointSize = pointSize
        self.gaugeTrackWidth = gaugeTrackWidth
        self.sliceGap = sliceGap
    }
}
