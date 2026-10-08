import SwiftUI
import AppKit

/// A panel add-on contributed by the host app, not the core: a button shown above the
/// Quit row, plus the page it opens (the core frames it with a Back button).
///
/// This is the extension seam: an app can register its own panel pages without
/// modifying the core. An app that registers none ships just this empty mechanism.
public struct PanelExtension: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    /// Builds the page body, given the current accent. Called lazily, when shown.
    public let makeContent: (_ accent: Color) -> AnyView

    public init(id: String,
                title: String,
                systemImage: String,
                makeContent: @escaping (_ accent: Color) -> AnyView) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.makeContent = makeContent
    }
}

/// A single outbound link the host app can surface in the panel (an upsell or
/// "learn more" link). Unlike `PanelExtension`, which opens an in-app page, this opens
/// a URL in the user's default browser. The core stays generic: the title, glyph, and
/// destination are all supplied by the host app.
public struct PromoLink {
    public let title: String
    public let systemImage: String
    public let url: URL

    public init(title: String, systemImage: String, url: URL) {
        self.title = title
        self.systemImage = systemImage
        self.url = url
    }
}

/// Registry of app-contributed panel extensions. Set once at launch (before any view
/// renders), the same way `Theme.configure` is used.
public enum PanelExtensions {
    public private(set) static var all: [PanelExtension] = []

    /// Register the app's panel extensions. Call once at launch.
    public static func register(_ extensions: [PanelExtension]) { all = extensions }

    /// An optional outbound link shown at the bottom of the panel **only when no
    /// extensions are registered** (so a host that contributes its own pages shows
    /// those instead). Set once at launch, like `register`.
    public private(set) static var promo: PromoLink?

    /// Set the panel's promo link. Call once at launch.
    public static func setPromo(_ link: PromoLink?) { promo = link }

    /// Open a promo link's destination in the user's default browser. The app itself
    /// makes no network request; macOS hands the URL to the default browser.
    @MainActor
    public static func open(_ link: PromoLink) {
        NSWorkspace.shared.open(link.url)
    }
}
