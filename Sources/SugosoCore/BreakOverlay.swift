import SwiftUI
import AppKit
import Combine

/// Presents a calming full-screen overlay when a break begins and tears it down
/// when focus resumes. The overlay fades in gently, shows the break countdown on
/// a Liquid Glass card, and is dismissed with ESC (or its button). While a break
/// is in progress it can be re-opened from the menu bar.
final class BreakOverlayController {
    private weak var timer: PomodoroTimer?
    private var window: OverlayWindow?
    private var keyMonitor: Any?
    private var cancellable: AnyCancellable?

    init(timer: PomodoroTimer) {
        self.timer = timer
        // React whenever the session kind changes (fires once with the current value too).
        cancellable = timer.$kind
            .removeDuplicates()
            .sink { [weak self] kind in self?.react(to: kind) }
    }

    private func react(to kind: SessionKind) {
        guard let timer else { return }
        switch kind {
        case .shortBreak, .longBreak:
            if timer.lockScreenOnBreak { show() }
        case .work:
            hide()
        }
    }

    /// Present the overlay. No-op if it's already visible. Safe to call from the menu.
    func show() {
        guard let timer, window == nil else { return }

        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let win = OverlayWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .screenSaver                 // above the menu bar / Dock, a "lock screen" feel
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        win.isReleasedWhenClosed = false
        win.hasShadow = false

        win.contentView = NSHostingView(rootView: BreakOverlayView(timer: timer) { [weak self] in self?.hide() })
        win.alphaValue = 0

        activateApp()
        win.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6                   // gentle fade-in
            win.animator().alphaValue = 1
        }

        // ESC dismisses the overlay (the timer keeps running underneath).
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {             // 53 == Escape
                self?.hide()
                return nil                       // swallow the key
            }
            return event
        }

        window = win
    }

    /// Fade the overlay out and close it. No-op if not visible.
    func hide() {
        guard let win = window else { return }
        window = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            win.animator().alphaValue = 0
        }, completionHandler: {
            win.orderOut(nil)
        })
    }

    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

/// A borderless window that is still allowed to become key, so it can receive the
/// ESC key press.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// The content of the break overlay.
struct BreakOverlayView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject private var brandingBox = BrandingBox.shared
    var onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.Palette.overlay.opacity(0.28).ignoresSafeArea()   // dim/tint the screen behind the glass

            VStack(spacing: Theme.Spacing.lg) {
                Text(timer.kind.symbol)
                    .font(.system(size: 64))
                    .accessibilityHidden(true)

                Text(timer.kind.title)
                    .font(.system(size: 30, weight: .semibold, design: Theme.brand.fontStyle.design))
                    .foregroundStyle(Theme.accent(for: timer.kind))

                Text(timer.clockText)
                    .font(.system(size: 104, weight: .bold, design: Theme.brand.fontStyle.design))
                    .monospacedDigit()
                    .accessibilityLabel("\(timer.clockText) of break remaining")

                Text("Step away for a bit. Focus resumes automatically.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(spacing: Theme.Spacing.xs) {
                    Button("Dismiss") { onDismiss() }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent(for: timer.kind))
                        .keyboardShortcut(.cancelAction)
                    Text("or press esc")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .padding(Theme.Spacing.xl + Theme.Spacing.md)
            .modifier(GlassCard(cornerRadius: Theme.Radius.lg * 2))
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { appeared = true } }
    }
}

/// Liquid Glass on macOS 26+, with a graceful material fallback on older systems.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.12)))
        }
    }
}
