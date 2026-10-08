import SwiftUI

/// The Tasks page: a reorderable, scrollable list with add / complete / delete.
/// Kept as its own view so a drag only re-renders this subtree (smooth drag).
/// `accent` is the current session color, passed in so the list stays on one
/// accent with the rest of the app.
struct TaskListView: View {
    @ObservedObject var tasks: TaskStore
    let accent: Color

    @State private var newTaskTitle = ""
    @State private var newTaskEstimate = 1
    @State private var draggingTaskID: UUID?
    @State private var dragOffsetY: CGFloat = 0
    @State private var dropTargetIndex: Int?

    private let rowHeight: CGFloat = 28
    private let rowSpacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Tasks").font(Theme.Typo.title)
                Spacer()
                if tasks.totalEstimate > 0 {
                    Text("\(tasks.totalDone)/\(tasks.totalEstimate)")
                        .font(Theme.Typo.counter).foregroundStyle(.secondary)
                }
                if tasks.tasks.contains(where: { $0.isComplete }) {
                    Button("Clear Done") { tasks.clearCompleted() }
                        .buttonStyle(.plain).font(Theme.Typo.label).foregroundStyle(.secondary)
                }
            }

            if tasks.tasks.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: rowSpacing) {
                        ForEach(Array(tasks.tasks.enumerated()), id: \.element.id) { index, task in
                            if showsIndicator(at: index) { dropIndicator }
                            taskRow(task)
                        }
                        if showsIndicator(at: tasks.tasks.count) { dropIndicator }
                    }
                    .padding(.vertical, 2)
                    .animation(.easeInOut(duration: 0.12), value: dropTargetIndex)
                }
                // Fixed height showing ~5.5 rows: the half-cut row signals that
                // the list scrolls, and the height stays put as tasks change.
                .frame(height: rowHeight * 5.5 + rowSpacing * 5)

                Text("Drag the handle to reorder. The top task starts the next focus session.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            addTaskRow
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("No Tasks Yet")
                .font(Theme.Typo.body).foregroundStyle(.secondary)
            Text("Add one below to track focus sessions against it.")
                .font(Theme.Typo.label).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func taskRow(_ task: TaskItem) -> some View {
        let isActive = task.id == tasks.activeTaskID
        let isDragging = task.id == draggingTaskID
        return HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .highPriorityGesture(dragGesture(for: task))
                .accessibilityLabel("Reorder \(task.title)")

            Button { tasks.toggleComplete(task.id) } label: {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(task.done >= task.estimate)   // fully-done tasks are locked complete
            .accessibilityLabel(task.isComplete ? "Mark \(task.title) not done" : "Mark \(task.title) done")

            Text(task.title)
                .strikethrough(task.isComplete)
                .foregroundStyle(task.isComplete ? Color.secondary : Color.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(task.done)/\(task.estimate)")
                .font(Theme.Typo.counter).foregroundStyle(.secondary)
                .accessibilityLabel("\(task.done) of \(task.estimate) focus sessions")

            Button { tasks.delete(task.id) } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(task.title)")
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .frame(height: rowHeight)
        .background(isActive ? Theme.Palette.wash(accent) : Color.clear,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .offset(y: isDragging ? dragOffsetY : 0)
        .zIndex(isDragging ? 1 : 0)
    }

    /// A line showing where a dragged task will drop (in the current accent).
    private var dropIndicator: some View {
        Capsule()
            .fill(accent)
            .frame(height: 3)
            .padding(.horizontal, Theme.Spacing.sm)
    }

    private func showsIndicator(at index: Int) -> Bool {
        draggingTaskID != nil && dropTargetIndex == index
    }

    /// Reorder by dragging the handle. A low-level DragGesture in the *global*
    /// coordinate space is used (the high-level reorder APIs don't fire in the
    /// menu-bar popover, and global coordinates avoid the offset feedback that
    /// made local-space dragging jitter). The move commits, animated, on release.
    private func dragGesture(for task: TaskItem) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { value in
                draggingTaskID = task.id
                dragOffsetY = value.translation.height
                if let start = tasks.tasks.firstIndex(where: { $0.id == task.id }) {
                    let raw = start + Int((value.translation.height / (rowHeight + rowSpacing)).rounded())
                    dropTargetIndex = min(max(raw, 0), tasks.tasks.count)
                }
            }
            .onEnded { _ in
                if let target = dropTargetIndex {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        tasks.move(task.id, toIndex: target)
                    }
                }
                draggingTaskID = nil
                dragOffsetY = 0
                dropTargetIndex = nil
            }
    }

    private var addTaskRow: some View {
        VStack(spacing: Theme.Spacing.sm) {
            TextField("Add a Task…", text: $newTaskTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTask)
            HStack {
                Stepper(value: $newTaskEstimate, in: 1...20) {
                    Text("Estimated: \(newTaskEstimate) Focus").font(Theme.Typo.label)
                }
                Spacer()
                Button("Add", action: addTask)
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addTask() {
        tasks.add(title: newTaskTitle, estimate: newTaskEstimate)
        newTaskTitle = ""
        newTaskEstimate = 1
    }
}
