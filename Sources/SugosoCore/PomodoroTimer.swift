import Foundation
import AppKit
import UserNotifications

/// The three kinds of session in a Pomodoro cycle.
enum SessionKind: Equatable {
    case work, shortBreak, longBreak

    var title: String {
        switch self {
        case .work:       return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak:  return "Long Break"
        }
    }

    var symbol: String {
        switch self {
        case .work:       return Theme.brand.workGlyph
        case .shortBreak: return Theme.brand.shortBreakGlyph
        case .longBreak:  return Theme.brand.longBreakGlyph
        }
    }
}

/// Drives the Pomodoro state machine: a focus session, then a short break,
/// with a longer break after every `pomodorosUntilLongBreak` focus sessions.
///
/// All mutation happens on the main thread (the timer is scheduled on the main
/// run loop), so the `@Published` values are always safe to read from SwiftUI.
final class PomodoroTimer: ObservableObject {

    // MARK: Configurable durations (persisted in UserDefaults)

    @Published var workMinutes: Int       { didSet { defaults.set(workMinutes, forKey: Keys.work); applyDurationChange(for: .work, oldMinutes: oldValue) } }
    @Published var shortBreakMinutes: Int { didSet { defaults.set(shortBreakMinutes, forKey: Keys.short); applyDurationChange(for: .shortBreak, oldMinutes: oldValue) } }
    @Published var longBreakMinutes: Int  { didSet { defaults.set(longBreakMinutes, forKey: Keys.long); applyDurationChange(for: .longBreak, oldMinutes: oldValue) } }

    @Published var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: Keys.notif) } }
    @Published var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Keys.sound) } }
    @Published var lockScreenOnBreak: Bool { didSet { defaults.set(lockScreenOnBreak, forKey: Keys.lock) } }

    @Published var pomodorosUntilLongBreak: Int { didSet { defaults.set(pomodorosUntilLongBreak, forKey: Keys.longEvery) } }

    // MARK: Live state

    @Published private(set) var kind: SessionKind = .work
    @Published private(set) var remaining: Int = 25 * 60     // seconds left in this session
    @Published private(set) var isRunning = false
    @Published private(set) var completedPomodoros = 0

    /// Current notification permission state, surfaced to the UI.
    @Published private(set) var notificationAuthorization: UNAuthorizationStatus = .notDetermined

    /// Called when a focus session finishes (timer reached zero, or skipped).
    var onFocusCompleted: (() -> Void)?

    /// Called when a focus session begins (Start pressed on focus, or a break ends).
    var onFocusBegan: (() -> Void)?

    /// Called when the cycle is reset, abandoning any in-progress focus session.
    var onFocusReset: (() -> Void)?

    private var timer: Timer?
    private var endDate: Date?            // when running, the wall-clock moment this session ends
    private let defaults: UserDefaults

    private enum Keys {
        static let work  = "workMinutes"
        static let short = "shortBreakMinutes"
        static let long  = "longBreakMinutes"
        static let notif = "notificationsEnabled"
        static let sound = "soundEnabled"
        static let lock  = "lockScreenOnBreak"
        static let longEvery = "pomodorosUntilLongBreak"
    }

    /// Read a persisted Int setting, clamping to a sane range. Without this, an
    /// externally-written or corrupted UserDefaults value (negative, zero, or
    /// enormous) could create a runaway zero-length session, overflow
    /// `minutes * 60`, or divide-by-zero in the long-break interval.
    private static func loadClampedInt(_ defaults: UserDefaults, _ key: String,
                                       fallback: Int, range: ClosedRange<Int>) -> Int {
        let value = defaults.object(forKey: key) as? Int ?? fallback
        return min(max(value, range.lowerBound), range.upperBound)
    }

    init(enableNotifications: Bool = true, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Load saved durations, falling back to the classic 25 / 5 / 15.
        workMinutes       = Self.loadClampedInt(defaults, Keys.work,  fallback: 25, range: 1...120)
        shortBreakMinutes = Self.loadClampedInt(defaults, Keys.short, fallback: 5,  range: 1...60)
        longBreakMinutes  = Self.loadClampedInt(defaults, Keys.long,  fallback: 15, range: 1...60)
        notificationsEnabled = defaults.object(forKey: Keys.notif) as? Bool ?? true
        soundEnabled = defaults.object(forKey: Keys.sound) as? Bool ?? true
        lockScreenOnBreak = defaults.object(forKey: Keys.lock) as? Bool ?? false
        pomodorosUntilLongBreak = Self.loadClampedInt(defaults, Keys.longEvery, fallback: 4, range: 1...12)
        remaining = workMinutes * 60
        if enableNotifications, notificationsAvailable {
            UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
            promptForNotificationPermission()
        }
    }

    // MARK: Controls

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        endDate = Date().addingTimeInterval(TimeInterval(remaining))
        if kind == .work { onFocusBegan?() }
        startTicking()
    }

    private func startTicking() {
        timer?.invalidate()
        // Tick a few times a second so the clock stays crisp and completion is
        // caught promptly. `remaining` is recomputed from `endDate`, so the
        // countdown stays accurate even across sleep/wake. .common mode keeps it
        // firing while the popover is open.
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func pause() {
        guard isRunning else { return }
        if let endDate {
            remaining = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        }
        isRunning = false
        endDate = nil
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        kind = .work
        completedPomodoros = 0
        remaining = duration(for: .work)
        endDate = nil
        onFocusReset?()
    }

    /// Jump to the next session now (also fires the begin notification/sound).
    func skip() { advance(notifying: true) }

    // MARK: Internals

    private func tick() {
        guard isRunning, let endDate else { return }
        let secs = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        if secs != remaining { remaining = secs }   // publish only on whole-second changes
        if endDate.timeIntervalSinceNow <= 0 { advance(notifying: true) }
    }

    /// Move to the next session in the cycle. Breaks/focus auto-continue running.
    private func advance(notifying: Bool) {
        let next: SessionKind
        switch kind {
        case .work:
            completedPomodoros += 1
            onFocusCompleted?()
            next = completedPomodoros % pomodorosUntilLongBreak == 0 ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            next = .work
        }

        if notifying { notifyTransition(to: next) }

        kind = next
        remaining = duration(for: next)
        if isRunning {
            endDate = Date().addingTimeInterval(TimeInterval(remaining))
            if next == .work { onFocusBegan?() }   // a new focus session begins
        }
    }

    /// Apply a duration edit to the on-screen countdown only when the current
    /// session is *pristine*: idle, of this kind, and still sitting at its full
    /// (pre-edit) length. That lets you dial in a duration before starting, while
    /// never resetting a session that's running or paused partway through.
    private func applyDurationChange(for changedKind: SessionKind, oldMinutes: Int) {
        guard !isRunning, kind == changedKind, remaining == oldMinutes * 60 else { return }
        remaining = duration(for: changedKind)
    }

    func duration(for kind: SessionKind) -> Int {
        switch kind {
        case .work:       return workMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak:  return longBreakMinutes * 60
        }
    }

    // MARK: Derived display values

    var clockText: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }

    /// Fractional progress (0...1) through the current session. When running it is
    /// computed from the wall-clock `endDate`, so the progress bar can advance
    /// smoothly between whole-second ticks.
    func progress(asOf date: Date = Date()) -> Double {
        let total = Double(duration(for: kind))
        guard total > 0 else { return 0 }
        let remainingExact: Double
        if isRunning, let endDate {
            remainingExact = max(0, endDate.timeIntervalSince(date))
        } else {
            remainingExact = Double(remaining)
        }
        return min(1, max(0, (total - remainingExact) / total))
    }

    // MARK: Notifications

    /// UNUserNotificationCenter requires a real bundle; guard so `swift run`
    /// (a bare binary) degrades gracefully instead of crashing.
    private var notificationsAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    /// Ask macOS for permission to show notifications. Only the first call shows
    /// the system prompt; after that the choice lives in System Settings.
    func promptForNotificationPermission() {
        guard notificationsAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            self?.refreshAuthorizationStatus()
        }
    }

    /// Read the current permission state into `notificationAuthorization`.
    func refreshAuthorizationStatus() {
        guard notificationsAvailable else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async { self?.notificationAuthorization = settings.authorizationStatus }
        }
    }

    /// Open System Settings ▸ Notifications (used when permission was denied).
    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }

    private func notifyTransition(to next: SessionKind) {
        let title: String, body: String
        switch next {
        case .work:       (title, body) = ("Break over ☕️", "Back to focus. Let's go.")
        case .shortBreak: (title, body) = ("Focus complete 🍅", "Nice work. Take a short break.")
        case .longBreak:  (title, body) = ("Long break time 🌴", "You've earned it. Step away for a bit.")
        }
        playTransitionSound()
        postNotification(title: title, body: body)
    }

    /// Play the custom transition chime when `Theme.brand.soundName` is set. The
    /// default (`soundName == nil`) rides the notification instead - see `postNotification`.
    private func playTransitionSound() {
        guard soundEnabled, let name = Theme.brand.soundName else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    private func postNotification(title: String, body: String) {
        guard notificationsAvailable, notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = (soundEnabled && Theme.brand.soundName == nil) ? .default : nil
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

/// Lets notifications appear (with sound) even when our app is the active app.
/// Without a delegate returning presentation options here, macOS silently
/// suppresses notifications posted while the app is in the foreground, which
/// is exactly when a break begins and the overlay activates the app.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
