import SwiftUI

/// A menu-bar-only app (no Dock icon; see LSUIElement in Info.plist) whose
/// single scene is the menu bar item. Lives in SugosoCore so a thin executable
/// launches the same scene via `SugosoApp.main()`.
public struct SugosoApp: App {
    @StateObject private var timer: PomodoroTimer
    @StateObject private var tasks: TaskStore
    private let overlay: BreakOverlayController
    /// Observe branding so the menu-bar label updates live when it changes.
    @ObservedObject private var brandingBox = BrandingBox.shared

    public init() {
        let model = PomodoroTimer()
        let store = TaskStore()
        model.onFocusBegan = { store.beginFocusSession() }
        model.onFocusCompleted = { store.completeFocusSession() }
        model.onFocusReset = { store.cancelFocusSession() }
        _timer = StateObject(wrappedValue: model)
        _tasks = StateObject(wrappedValue: store)
        overlay = BreakOverlayController(timer: model)
    }

    public var body: some Scene {
        MenuBarExtra {
            MenuContentView(timer: timer, tasks: tasks, overlay: overlay)
        } label: {
            // MenuBarExtra forces the system font on a Text label (ignoring weight
            // and baseline), so we render our own image for full control.
            Image(nsImage: MenuBarLabel.image(symbol: timer.kind.symbol,
                                              time: timer.clockText,
                                              showGlyph: Theme.brand.menuBarShowsGlyph,
                                              showTime: Theme.brand.menuBarShowsTime))
                .renderingMode(.original)
        }
        // .window gives us a small SwiftUI panel (so Steppers etc. work),
        // instead of a plain system menu.
        .menuBarExtraStyle(.window)
    }
}
