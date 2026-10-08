import Foundation

/// A single to-do item, tracked in pomodoros: an estimate versus the number of
/// pomodoros actually completed, like pomofocus.io's task list.
struct TaskItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var estimate: Int          // estimated pomodoros
    var done: Int = 0          // completed ("act") pomodoros
    var isComplete: Bool = false
}

/// Holds the task list and the active task for the in-progress focus session,
/// persisting tasks to UserDefaults as JSON. Pure model (no UI), unit-testable.
///
/// The active task is taken from the top-most incomplete task at the start of a
/// focus session and highlighted while that session runs. Reordering mid-session
/// does not change it; the next focus session adopts the new top task. There is
/// no active task during breaks or while idle.
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    /// The task earning the current focus session (nil during breaks / when idle).
    @Published private(set) var activeTaskID: UUID?

    private let defaults: UserDefaults
    private enum Keys { static let tasks = "tasks" }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var activeTask: TaskItem? { tasks.first { $0.id == activeTaskID } }

    // MARK: Editing

    func add(title: String, estimate: Int) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.append(TaskItem(title: String(trimmed.prefix(200)), estimate: Self.clampEstimate(estimate)))
        persist()
    }

    func delete(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        if activeTaskID == id { activeTaskID = nil }
        persist()
    }

    func toggleComplete(_ id: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        guard tasks[i].done < tasks[i].estimate else { return }  // fully done -> locked complete
        tasks[i].isComplete.toggle()
        persist()
    }

    func clearCompleted() {
        tasks.removeAll { $0.isComplete }
        if let id = activeTaskID, !tasks.contains(where: { $0.id == id }) { activeTaskID = nil }
        persist()
    }

    /// Move a task so it lands at the given insertion index (0...count).
    func move(_ id: UUID, toIndex target: Int) {
        guard let from = tasks.firstIndex(where: { $0.id == id }) else { return }
        var insert = min(max(target, 0), tasks.count)
        let item = tasks.remove(at: from)
        if insert > from { insert -= 1 }   // account for the removal shifting indices
        tasks.insert(item, at: min(max(insert, 0), tasks.count))
        persist()
    }

    // MARK: Focus-session lifecycle (driven by the timer)

    /// Make the top task active for the focus session that's starting. No-op if a
    /// session is already active (e.g. resuming after a pause).
    func beginFocusSession() {
        if activeTaskID == nil { activeTaskID = firstIncompleteID() }
    }

    /// Credit the active task with one pomodoro and end the session. The count is
    /// capped at the estimate, and reaching the estimate auto-completes the task.
    func completeFocusSession() {
        if let id = activeTaskID, let i = tasks.firstIndex(where: { $0.id == id }) {
            tasks[i].done = min(tasks[i].done + 1, tasks[i].estimate)
            if tasks[i].done >= tasks[i].estimate {
                tasks[i].isComplete = true
            }
            persist()
        }
        activeTaskID = nil
    }

    /// End the session without crediting (e.g. on reset).
    func cancelFocusSession() {
        activeTaskID = nil
    }

    // MARK: Derived

    var totalDone: Int { tasks.reduce(0) { $0 + $1.done } }
    var totalEstimate: Int { tasks.reduce(0) { $0 + $1.estimate } }

    // MARK: Internals

    private func firstIncompleteID() -> UUID? { tasks.first { !$0.isComplete }?.id }
    private static func clampEstimate(_ value: Int) -> Int { min(max(value, 1), 60) }

    private func persist() {
        if let data = try? JSONEncoder().encode(tasks) { defaults.set(data, forKey: Keys.tasks) }
    }

    private func load() {
        guard let data = defaults.data(forKey: Keys.tasks),
              let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) else { return }
        // Sanitize persisted values defensively (same-user local store).
        tasks = decoded.map { item in
            var t = item
            t.title = String(t.title.prefix(200))
            t.estimate = Self.clampEstimate(t.estimate)
            t.done = min(max(0, t.done), t.estimate)   // never exceeds estimate; also prevents overflow
            return t
        }
    }
}
