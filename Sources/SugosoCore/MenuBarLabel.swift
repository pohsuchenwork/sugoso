import SwiftUI
import AppKit

/// MenuBarExtra renders a `Text` label with the system menu-bar font and ignores
/// weight / baseline modifiers. To get a genuinely **bold**, precisely positioned
/// label we render our own SwiftUI content to an image and hand that to the bar.
@MainActor
enum MenuBarLabel {
    /// Vertical nudge in points. Positive = lower on screen, negative = higher.
    static let verticalNudge: CGFloat = -1

    /// Font sizes / weight; tune freely. These render as real pixels, so the
    /// menu bar can't override them.
    static let emojiSize: CGFloat = 14
    static let timeSize: CGFloat = 13
    static let timeWeight: Font.Weight = .regular
    static let timeColor: Color = .black

    /// `showGlyph` / `showTime` are the menu-bar display options. If both are off we
    /// still render the glyph, so the menu bar item is never blank/unclickable.
    static func image(symbol: String, time: String,
                      showGlyph: Bool = true, showTime: Bool = true) -> NSImage {
        let glyphVisible = showGlyph || !showTime
        let content = HStack(spacing: 4) {
            if glyphVisible {
                Text(symbol)
                    .font(.system(size: emojiSize))
            }
            if showTime {
                Text(time)
                    .font(.system(size: timeSize, weight: timeWeight).monospacedDigit())
                    .foregroundStyle(timeColor)
            }
        }
        .padding(.top, max(0, verticalNudge))
        .padding(.bottom, max(0, -verticalNudge))

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return NSImage() }
        image.isTemplate = false   // keep the emoji in color
        return image
    }
}
