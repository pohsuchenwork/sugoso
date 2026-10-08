import SwiftUI
import AppKit

/// The single source of truth for the visual system. See DESIGN.md for the brief.
/// Calm, focused, native: neutral base, one state-driven accent (terracotta for
/// focus, sage for breaks), a 4-pt spacing scale, and SF Pro / SF Pro Rounded.
///
/// The design tokens (Spacing/Radius/Typo/Palette) are **public** so apps built on
/// the core can compose views in the same system. The accent colors and timer font
/// are read from the current `Branding` (`Theme.brand` / `Theme.configure`).
public enum Theme {

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
    }

    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 14
    }

    public enum Palette {
        /// Focus accent - a muted terracotta (the Pomodoro tomato) by default, from
        /// the current branding.
        public static var focus: Color {
            Color.appearanceAware(light: Theme.brand.focus.light, dark: Theme.brand.focus.dark)
        }
        /// Short-break accent, from the current branding.
        public static var shortBreak: Color {
            Color.appearanceAware(light: Theme.brand.shortBreak.light, dark: Theme.brand.shortBreak.dark)
        }
        /// Long-break accent, from the current branding.
        public static var longBreak: Color {
            Color.appearanceAware(light: Theme.brand.longBreak.light, dark: Theme.brand.longBreak.dark)
        }
        /// Break ("lock") screen background tint, from the current branding.
        public static var overlay: Color {
            Color.appearanceAware(light: Theme.brand.overlayColor.light, dark: Theme.brand.overlayColor.dark)
        }
        /// Tint behind the active task / selected state (very low alpha).
        public static func wash(_ color: Color) -> Color { color.opacity(0.16) }
    }

    /// The one accent for the current session - color encodes which session you're in.
    static func accent(for kind: SessionKind) -> Color {
        switch kind {
        case .work:       return Palette.focus
        case .shortBreak: return Palette.shortBreak
        case .longBreak:  return Palette.longBreak
        }
    }

    public enum Typo {
        /// The big countdown numerals - font design follows the brand's `fontStyle`.
        public static var timer: Font   { Font.system(size: 46, weight: .semibold, design: Theme.brand.fontStyle.design) }
        public static var counter: Font { Font.system(.callout, design: Theme.brand.fontStyle.design).monospacedDigit() }
        public static let title        = Font.headline
        public static let body         = Font.callout
        public static let label        = Font.caption
        public static let sectionLabel = Font.caption2.weight(.semibold)
    }
}

extension Theme {
    /// The default branding - and the fallback when `configure` is never called
    /// (e.g. the `--run-tests` path). These values live here, once, and use the same
    /// sage for both break kinds.
    public static let freeDefault = Branding(
        appName: "Sugoso",
        focus: .init(light: (0.76, 0.31, 0.23), dark: (0.86, 0.42, 0.32)),
        shortBreak: .init(light: (0.34, 0.53, 0.46), dark: (0.51, 0.68, 0.60)),
        longBreak: .init(light: (0.34, 0.53, 0.46), dark: (0.51, 0.68, 0.60)),
        workGlyph: "🍅", shortBreakGlyph: "☕️", longBreakGlyph: "🌴"
    )

    /// The branding in effect for this process (held in `BrandingBox` so views update
    /// live when it changes).
    public static var brand: Branding { BrandingBox.shared.current }

    /// Apply branding. Call at launch, and any time it changes at runtime - views
    /// observing `BrandingBox.shared` re-render.
    public static func configure(_ branding: Branding) { BrandingBox.shared.current = branding }
}

/// Observable holder for the active `Branding`, so SwiftUI views update live when the
/// branding changes at runtime. Views observe `BrandingBox.shared`; value reads go
/// through `Theme.brand`.
public final class BrandingBox: ObservableObject {
    public static let shared = BrandingBox()
    @Published public internal(set) var current: Branding = Theme.freeDefault
    private init() {}
}

extension BrandFont {
    /// The SwiftUI font design for this style.
    public var design: Font.Design {
        switch self {
        case .rounded:    return .rounded
        case .system:     return .default
        case .monospaced: return .monospaced
        case .serif:      return .serif
        }
    }
}

extension Color {
    /// A color that resolves to different sRGB values in light vs dark appearance,
    /// so brand colors stay legible in both without an asset catalog.
    static func appearanceAware(light: (Double, Double, Double),
                                dark: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}
