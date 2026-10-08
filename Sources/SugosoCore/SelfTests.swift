import Foundation

/// Lightweight, framework-free tests for the PomodoroTimer state machine.
///
/// Command Line Tools (without full Xcode) ship neither XCTest nor Swift
/// Testing, so these run as a plain executable mode: `swift run Sugoso
/// --run-tests`. The assertions translate directly to XCTest/`#expect` if you
/// later add a real test target under Xcode.
public enum SelfTests {
    public static func runAndExit() -> Never {
        var failures = 0
        func check(_ passed: @autoclosure () -> Bool, _ description: String) {
            if passed() {
                print("  ✓ \(description)")
            } else {
                print("  ✗ \(description)")
                failures += 1
            }
        }

        /// A timer on a unique throwaway defaults suite, notifications off.
        func makeTimer() -> PomodoroTimer {
            let suite = "SelfTests-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let timer = PomodoroTimer(enableNotifications: false, defaults: defaults)
            timer.notificationsEnabled = false
            return timer
        }

        print("PomodoroTimer state-machine self-tests\n")

        do {
            let t = makeTimer()
            check(t.kind == .work, "starts in a focus session")
            check(t.remaining == 25 * 60, "starts at 25:00")
            check(!t.isRunning, "starts paused")
            check(t.completedPomodoros == 0, "starts with 0 completed pomodoros")
        }

        do {
            let t = makeTimer()
            var sequence: [SessionKind] = []
            for _ in 0..<8 { t.skip(); sequence.append(t.kind) }
            check(sequence == [.shortBreak, .work, .shortBreak, .work,
                               .shortBreak, .work, .longBreak,  .work],
                  "cycles focus→break with a long break every 4th focus")
            check(t.completedPomodoros == 4, "counts 4 pomodoros after 4 focus sessions")
        }

        do {
            // Configurable long-break interval: 3 -> short, short, long.
            let t = makeTimer()
            t.pomodorosUntilLongBreak = 3
            var sequence: [SessionKind] = []
            for _ in 0..<6 { t.skip(); sequence.append(t.kind) }
            check(sequence == [.shortBreak, .work, .shortBreak, .work, .longBreak, .work],
                  "long-break interval of 3 yields short, short, long")
        }

        do {
            let t = makeTimer()
            t.skip()
            check(t.kind == .shortBreak && t.remaining == t.shortBreakMinutes * 60,
                  "skipping into a short break sets its duration")
            t.skip()
            check(t.kind == .work && t.remaining == t.workMinutes * 60,
                  "skipping back to focus sets its duration")
        }

        do {
            let t = makeTimer()
            t.skip(); t.skip(); t.skip()
            t.reset()
            check(t.kind == .work && t.completedPomodoros == 0
                  && t.remaining == t.workMinutes * 60 && !t.isRunning,
                  "reset returns to a fresh focus session")
        }

        do {
            let t = makeTimer()
            t.workMinutes = 30
            check(t.remaining == 30 * 60, "editing a duration while pristine updates the display")
        }

        do {
            let t = makeTimer()
            t.shortBreakMinutes = 10
            check(t.remaining == t.workMinutes * 60, "editing another kind's duration leaves the current session")
        }

        do {
            let t = makeTimer()
            let before = t.remaining
            t.start()
            t.workMinutes = 30
            check(t.remaining == before, "editing a duration while running does not reset the countdown")
            t.pause()
        }

        do {
            let t = makeTimer()
            check(abs(t.progress(asOf: Date())) < 0.0001, "progress is 0 at the start of a session")
        }

        do {
            // Untrusted / corrupted persisted durations must be clamped, not trusted.
            let suite = "SelfTests-\(UUID().uuidString)"
            let d = UserDefaults(suiteName: suite)!
            d.removePersistentDomain(forName: suite)
            d.set(100_000_000_000, forKey: "workMinutes")   // would overflow minutes * 60
            d.set(-5, forKey: "shortBreakMinutes")          // negative
            d.set(0,  forKey: "longBreakMinutes")           // zero -> runaway session
            let t = PomodoroTimer(enableNotifications: false, defaults: d)
            t.notificationsEnabled = false
            check((1...120).contains(t.workMinutes), "huge persisted focus duration is clamped")
            check((1...60).contains(t.shortBreakMinutes), "negative persisted short break is clamped")
            check((1...60).contains(t.longBreakMinutes), "zero persisted long break is clamped")
        }

        do {
            // Task list (pomofocus-style)
            let suite = "SelfTests-\(UUID().uuidString)"
            let d = UserDefaults(suiteName: suite)!
            d.removePersistentDomain(forName: suite)
            let store = TaskStore(defaults: d)
            check(store.tasks.isEmpty, "task store starts empty")
            store.add(title: "   ", estimate: 1)
            check(store.tasks.isEmpty, "blank task titles are ignored")
            store.add(title: "Write report", estimate: 3)
            check(store.tasks.count == 1, "adding a task appends it")
            check(store.activeTaskID == nil, "no active task until a focus session starts")
            store.beginFocusSession()
            check(store.activeTaskID == store.tasks.first?.id, "starting a focus makes the top task active")
            store.completeFocusSession()
            check(store.tasks.first?.done == 1, "a completed focus credits the active task")
            check(store.activeTaskID == nil, "no active task during a break")
            let reloaded = TaskStore(defaults: d)
            check(reloaded.tasks.first?.done == 1, "tasks persist across launches")
            if let id = store.tasks.first?.id { store.toggleComplete(id) }
            check(store.tasks.first?.isComplete == true, "toggling marks a task complete")
            store.clearCompleted()
            check(store.tasks.isEmpty, "clear done removes completed tasks")
        }

        do {
            // Reorder + "credit the task that was started" semantics.
            let suite = "SelfTests-\(UUID().uuidString)"
            let d = UserDefaults(suiteName: suite)!
            d.removePersistentDomain(forName: suite)
            let store = TaskStore(defaults: d)
            store.add(title: "A", estimate: 2)
            store.add(title: "B", estimate: 2)
            let bID = store.tasks.first(where: { $0.title == "B" })!.id
            store.beginFocusSession()              // locks onto A (top)
            store.move(bID, toIndex: 0)            // drag B to the top
            check(store.tasks.first?.title == "B", "reordering moves a task to a new index")
            store.completeFocusSession()                                // still credits A
            check(store.tasks.first(where: { $0.title == "A" })?.done == 1
                  && store.tasks.first(where: { $0.title == "B" })?.done == 0,
                  "the started task is credited even after reordering")
            store.beginFocusSession()                                   // locks onto new top (B)
            store.completeFocusSession()
            check(store.tasks.first(where: { $0.title == "B" })?.done == 1,
                  "the next focus credits the new top task")
        }

        do {
            // Ticking a task off must not disturb the active focus session.
            let suite = "SelfTests-\(UUID().uuidString)"
            let d = UserDefaults(suiteName: suite)!
            d.removePersistentDomain(forName: suite)
            let store = TaskStore(defaults: d)
            store.add(title: "A", estimate: 2)
            store.add(title: "B", estimate: 2)
            let aID = store.tasks.first(where: { $0.title == "A" })!.id
            let bID = store.tasks.first(where: { $0.title == "B" })!.id
            store.beginFocusSession()                       // active = A
            store.toggleComplete(aID)                       // tick A while it's active
            check(store.activeTaskID == aID, "ticking the active task keeps it active")
            store.completeFocusSession()                    // still credits A
            check(store.tasks.first(where: { $0.id == aID })?.done == 1,
                  "a ticked-off active task is still credited")
            store.beginFocusSession()                       // next focus ignores ticked A
            check(store.activeTaskID == bID, "a new focus skips ticked-off tasks")
        }

        do {
            // Hitting the estimate caps the count and auto-completes the task.
            let suite = "SelfTests-\(UUID().uuidString)"
            let d = UserDefaults(suiteName: suite)!
            d.removePersistentDomain(forName: suite)
            let store = TaskStore(defaults: d)
            store.add(title: "One-pom", estimate: 1)
            let id = store.tasks.first!.id
            store.beginFocusSession()
            store.completeFocusSession()
            check(store.tasks.first?.done == 1, "the count stops at the estimate (no 2/1)")
            check(store.tasks.first(where: { $0.id == id })?.isComplete == true,
                  "reaching the estimate auto-completes the task")
        }

        do {
            // Crafted/corrupted persisted tasks are clamped on load (no overflow).
            let suite = "SelfTests-\(UUID().uuidString)"
            let d = UserDefaults(suiteName: suite)!
            d.removePersistentDomain(forName: suite)
            let crafted = [TaskItem(title: "x", estimate: 2, done: 1_000_000)]
            d.set(try! JSONEncoder().encode(crafted), forKey: "tasks")
            let store = TaskStore(defaults: d)
            check(store.tasks.first?.done == 2, "persisted 'done' is clamped to the estimate on load")
        }

        do {
            // A fully-done task (done == estimate) is locked complete; can't un-tick.
            let suite = "SelfTests-\(UUID().uuidString)"
            let d = UserDefaults(suiteName: suite)!
            d.removePersistentDomain(forName: suite)
            let store = TaskStore(defaults: d)
            store.add(title: "A", estimate: 1)
            let id = store.tasks.first!.id
            store.beginFocusSession()
            store.completeFocusSession()            // done 1/1 -> auto-completes
            check(store.tasks.first?.isComplete == true, "reaching the estimate completes the task")
            store.toggleComplete(id)                 // attempt to un-tick
            check(store.tasks.first?.isComplete == true, "a fully-done task can't be un-ticked")
        }

        print("\n" + (failures == 0 ? "All tests passed ✅" : "\(failures) test(s) failed ❌"))
        exit(failures == 0 ? 0 : 1)
    }
}
