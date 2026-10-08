import SwiftUI
import AppKit
import UserNotifications

/// The panel shown when you click the menu bar item: a main page (timer,
/// controls, settings), a Tasks page, and any app-contributed extension pages,
/// each reached via a button. Visual system in Theme.swift / DESIGN.md.
struct MenuContentView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var tasks: TaskStore
    let overlay: BreakOverlayController
    /// Observe branding so colors/glyphs update live when it changes.
    @ObservedObject private var brandingBox = BrandingBox.shared

    private enum Page { case main, tasks, ext(String) }
    @State private var page: Page = .main

    /// The one accent on screen - terracotta in focus, sage in break.
    private var accent: Color { Theme.accent(for: timer.kind) }

    var body: some View {
        Group {
            switch page {
            case .main:        mainPage
            case .tasks:       tasksPage
            case .ext(let id): extensionPage(id)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 288)
        .onAppear { timer.refreshAuthorizationStatus() }
    }

    // MARK: Pages

    private var mainPage: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            header
            countdown
            controls
            breakScreenButton
            tasksSection

            section("Durations") { settings }
            section("Alerts") {
                toggles
                notificationAccess
            }

            bottomExtras

            Button { NSApplication.shared.terminate(nil) } label: {
                Text("Quit \(Theme.brand.appName)").frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(Theme.Typo.body)
            .keyboardShortcut("q", modifiers: .command)
            .accessibilityLabel("Quit \(Theme.brand.appName)")
        }
    }

    private var tasksPage: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            backButton
            TaskListView(tasks: tasks, accent: accent)
        }
    }

    /// An app-contributed extension sub-page (mirrors the Tasks page). The page body
    /// comes from the host app; the core only frames it with a Back button.
    @ViewBuilder
    private func extensionPage(_ id: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            backButton
            if let ext = PanelExtensions.all.first(where: { $0.id == id }) {
                ext.makeContent(accent)
            }
        }
    }

    /// Shared Back button (returns to the main page).
    private var backButton: some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { page = .main } } label: {
            Label("Back", systemImage: "chevron.left")
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.trailing, Theme.Spacing.lg)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to timer")
    }

    /// A typographic section header + its content, grouped by whitespace.
    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typo.sectionLabel)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.6)
            content()
        }
    }

    // MARK: Timer

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(timer.kind.symbol)
                .font(.title)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(timer.kind.title).font(Theme.Typo.title)
                Group {
                    if let active = tasks.activeTask {
                        Text(active.title).lineLimit(1)
                    } else {
                        Text("\(timer.completedPomodoros) Completed")
                    }
                }
                .font(Theme.Typo.label)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var countdown: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(timer.clockText)
                .font(Theme.Typo.timer)
                .monospacedDigit()
                .accessibilityLabel("\(timer.clockText) remaining")
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                ProgressView(value: timer.progress(asOf: context.date))
                    .tint(accent)
                    .transaction { $0.animation = nil }
            }
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(timer.isRunning ? "Pause" : "Start") { timer.toggle() }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            Button("Skip") { timer.skip() }
                .buttonStyle(.bordered)
            Button("Reset") { timer.reset() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var breakScreenButton: some View {
        if timer.kind != .work {
            Button { overlay.show() } label: {
                Label("Show Break Screen", systemImage: "rectangle.inset.filled")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(accent)
        }
    }

    private var tasksButton: some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { page = .tasks } } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checklist")
                Text("Tasks").font(Theme.Typo.body)
                Spacer()
                if tasks.totalEstimate > 0 {
                    Text("\(tasks.totalDone)/\(tasks.totalEstimate)")
                        .font(Theme.Typo.counter).foregroundStyle(.secondary)
                } else if !tasks.tasks.isEmpty {
                    Text("\(tasks.tasks.count)").font(Theme.Typo.counter).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, Theme.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tasks")
        .accessibilityHint("Opens the task list")
    }

    /// The Tasks navigation button, fenced by dividers to match the extension row.
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Divider()
            tasksButton
            Divider()
        }
    }

    /// Bottom-of-panel extras: registered extension button(s) if any; otherwise an
    /// optional promo link; otherwise just the settings/Quit separator. The button group
    /// is fenced by dividers so it hugs its lines instead of floating in the wide spacing.
    @ViewBuilder
    private var bottomExtras: some View {
        if !PanelExtensions.all.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Divider()
                ForEach(PanelExtensions.all) { ext in
                    Button { withAnimation(.easeInOut(duration: 0.15)) { page = .ext(ext.id) } } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: ext.systemImage)
                            Text(ext.title).font(Theme.Typo.body)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ext.title)
                }
                Divider()
            }
        } else if let promo = PanelExtensions.promo {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Divider()
                Button { PanelExtensions.open(promo) } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: promo.systemImage)
                        Text(promo.title).font(Theme.Typo.body)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(promo.title)
                .accessibilityHint("Opens in your browser")
                Divider()
            }
        } else {
            Divider()
        }
    }

    // MARK: Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Stepper("Focus: \(timer.workMinutes) min", value: $timer.workMinutes, in: 1...120)
            Stepper("Short Break: \(timer.shortBreakMinutes) min", value: $timer.shortBreakMinutes, in: 1...60)
            HStack(spacing: Theme.Spacing.sm) {
                Stepper(value: $timer.longBreakMinutes, in: 1...60) {
                    Text("Long Break: \(timer.longBreakMinutes) min")
                }
                Stepper(value: $timer.pomodorosUntilLongBreak, in: 1...12) {
                    Text("Every \(timer.pomodorosUntilLongBreak) Focus")
                }
            }
        }
        .font(Theme.Typo.body)
    }

    private var toggles: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Toggle("Notifications", isOn: $timer.notificationsEnabled)
            Toggle("Sound", isOn: $timer.soundEnabled)
                .disabled(!timer.notificationsEnabled)
            Toggle("Lock Screen on Break", isOn: $timer.lockScreenOnBreak)
        }
        .toggleStyle(.switch)
        .tint(accent)
        .font(Theme.Typo.body)
    }

    @ViewBuilder
    private var notificationAccess: some View {
        switch timer.notificationAuthorization {
        case .notDetermined:
            Button("Enable Notifications…") { timer.promptForNotificationPermission() }
                .buttonStyle(.bordered)
                .tint(accent)
                .frame(maxWidth: .infinity)
        case .denied:
            Button { timer.openNotificationSettings() } label: {
                Label("Turn on Notifications in Settings", systemImage: "bell.slash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .font(Theme.Typo.label)
        default:
            EmptyView()
        }
    }
}
