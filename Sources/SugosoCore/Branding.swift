/// Branding - the cosmetic configuration the app applies at launch (and whenever it
/// changes at runtime). Selected via `Theme.configure(_:)`; held in `BrandingBox` so
/// views update live. Everything else is shared in SugosoCore.
public struct Branding {
    /// sRGB triples for light and dark appearance (matches `Color.appearanceAware`).
    public struct ColorSpec {
        public let light: (Double, Double, Double)
        public let dark: (Double, Double, Double)
        public init(light: (Double, Double, Double), dark: (Double, Double, Double)) {
            self.light = light
            self.dark = dark
        }
    }

    public let appName: String           // e.g. "Sugoso" → "Quit <appName>"
    public let focus: ColorSpec          // focus accent (terracotta by default)
    public let shortBreak: ColorSpec     // short-break accent (sage by default)
    public let longBreak: ColorSpec      // long-break accent (sage by default)
    public let overlayColor: ColorSpec   // break ("lock") screen background tint (black by default)
    public let workGlyph: String         // session glyph for focus
    public let shortBreakGlyph: String   // session glyph for a short break
    public let longBreakGlyph: String    // session glyph for a long break
    public let menuBarShowsGlyph: Bool   // show the session glyph in the menu bar
    public let menuBarShowsTime: Bool    // show the countdown in the menu bar
    public let fontStyle: BrandFont      // font design for the timer numerals
    public let soundName: String?        // custom transition chime; nil = system default

    public init(appName: String,
                focus: ColorSpec,
                shortBreak: ColorSpec,
                longBreak: ColorSpec,
                overlayColor: ColorSpec = ColorSpec(light: (0.0, 0.0, 0.0), dark: (0.0, 0.0, 0.0)),
                workGlyph: String,
                shortBreakGlyph: String,
                longBreakGlyph: String,
                menuBarShowsGlyph: Bool = true,
                menuBarShowsTime: Bool = true,
                fontStyle: BrandFont = .rounded,
                soundName: String? = nil) {
        self.appName = appName
        self.focus = focus
        self.shortBreak = shortBreak
        self.longBreak = longBreak
        self.overlayColor = overlayColor
        self.workGlyph = workGlyph
        self.shortBreakGlyph = shortBreakGlyph
        self.longBreakGlyph = longBreakGlyph
        self.menuBarShowsGlyph = menuBarShowsGlyph
        self.menuBarShowsTime = menuBarShowsTime
        self.fontStyle = fontStyle
        self.soundName = soundName
    }
}

/// The font design used for the timer numerals. Plain (no SwiftUI) so it can live in
/// Branding; `Theme` maps it to a `Font.Design`.
public enum BrandFont: String, CaseIterable {
    case rounded, system, monospaced, serif

    /// Human-readable name for pickers.
    public var label: String {
        switch self {
        case .rounded:    return "Rounded"
        case .system:     return "System"
        case .monospaced: return "Mono"
        case .serif:      return "Serif"
        }
    }
}
