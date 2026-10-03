import AppKit
import SwiftUI

enum Page { case timer, tasks, collection }

/// The whole app in one view: a header, the current page, and three buttons at the bottom.
/// Used in the menu-bar dropdown and in the floating window.
@MainActor
struct MainView: View {
    enum Placement { case menu, panel }

    let placement: Placement
    @ObservedObject private var model = PomodoroModel.shared
    @ObservedObject private var sessions = SessionStore.shared
    @ObservedObject private var panel = FloatingPanelController.shared
    @State private var page: Page = .timer

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch page {
                case .timer: TimerPage()
                case .tasks: TasksPage()
                case .collection: CollectionPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            BottomBar(page: $page)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.ink)
        .tint(Theme.red)
        .environment(\.colorScheme, .light)
        .frame(width: placement == .menu ? 300 : nil, height: placement == .menu ? 400 : nil)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(nsImage: TomatoArt.image("zen"))
                .resizable()
                .frame(width: 18, height: 18)
            Text("\(sessions.points(on: Date())) Pkt heute")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Spacer()
            if placement == .menu {
                IconButton(systemImage: "pin", help: "Als schwebendes Fenster öffnen") { panel.show() }
            } else {
                IconButton(systemImage: "chevron.up", help: "Einklappen") { panel.toggleCollapsed() }
            }
            Menu {
                if placement == .panel {
                    Button("Fenster schließen") { panel.hide() }
                }
                Button("Beenden") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

// MARK: - Bottom bar

@MainActor
struct BottomBar: View {
    @Binding var page: Page
    @ObservedObject private var model = PomodoroModel.shared

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
            HStack {
                sideButton(.tasks, help: "Aufgaben") {
                    Image(systemName: "checklist").font(.system(size: 17, weight: .medium))
                }
                Spacer()
                Button {
                    model.toggle()
                    page = .timer
                } label: {
                    Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Theme.red))
                }
                .buttonStyle(.plain)
                .help(model.isRunning ? "Pause" : "Start")
                Spacer()
                sideButton(.collection, help: "Sammlung") {
                    Image(nsImage: TomatoArt.image("happy"))
                        .resizable()
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 10)
        }
    }

    /// Tap opens the page, tap again goes back to the timer.
    private func sideButton<Icon: View>(_ target: Page, help: String, @ViewBuilder icon: () -> Icon) -> some View {
        let selected = page == target
        return Button {
            page = selected ? .timer : target
        } label: {
            VStack(spacing: 4) {
                icon()
                    .foregroundStyle(selected ? Theme.red : Theme.muted)
                    .frame(width: 28, height: 28)
                Circle()
                    .fill(selected ? Theme.red : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Timer

@MainActor
struct TimerPage: View {
    @ObservedObject private var model = PomodoroModel.shared
    @ObservedObject private var tasks = TaskStore.shared

    var body: some View {
        VStack(spacing: 14) {
            if model.reviewPending {
                ReviewView()
            } else if model.mode == .rest {
                breakView
            } else if model.breakFinished {
                nextSessionView
            } else {
                focusView
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var focusView: some View {
        VStack(spacing: 14) {
            BigClock(color: model.isRunning ? Theme.red : Theme.ink)
            ProgressLine(value: model.progress, color: Theme.red)

            if !model.hasSession {
                DurationSlider()
            } else if !model.isRunning {
                TextButton("Session beenden") { model.reset() }
            }

            if let next = tasks.next {
                VStack(spacing: 2) {
                    Text("Nächste Aufgabe")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                    Text(next.title)
                        .font(.callout)
                        .lineLimit(1)
                }
            }
        }
    }

    /// The automatic break after a completed session: reward on top, green countdown below.
    private var breakView: some View {
        VStack(spacing: 12) {
            if let session = model.lastSession {
                RewardView(session: session)
                    .frame(maxHeight: .infinity)
            }
            VStack(spacing: 6) {
                Text("Pause · \(model.clock)")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.green)
                ProgressLine(value: model.progress, color: Theme.green)
            }
            TextButton("Pause überspringen") { model.startNextSession() }
        }
    }

    private var nextSessionView: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Text("Pause vorbei")
                .font(.headline)
            Button { model.startNextSession() } label: {
                Text("Nächste Session starten")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.red))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            DurationSlider()
        }
    }
}

@MainActor
struct BigClock: View {
    @ObservedObject private var model = PomodoroModel.shared
    let color: Color

    var body: some View {
        Text(model.clock)
            .font(.system(size: 160, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.1)
            .lineLimit(1)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 48, maxHeight: .infinity)
            .layoutPriority(1)
    }
}

struct ProgressLine: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.hairline)
                Capsule().fill(color).frame(width: geo.size.width * value)
            }
        }
        .frame(height: 4)
    }
}

@MainActor
struct DurationSlider: View {
    @ObservedObject private var model = PomodoroModel.shared

    var body: some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: { Double(model.minutes) },
                    set: { model.setMinutes(Int($0.rounded())) }
                ),
                in: PomodoroModel.minuteRange,
                step: 1
            )
            .tint(Theme.red)
            Text(sliderCaption)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
    }

    /// "25 min → Fokus" — which tomato this length would earn.
    private var sliderCaption: String {
        guard let tomato = TomatoRules.tomato(forMinutes: model.minutes) else {
            return "\(model.minutes) min · noch keine Tomate"
        }
        return "\(model.minutes) min → \(tomato.name), \(tomato.points) Pkt"
    }
}

@MainActor
struct RewardView: View {
    let session: FocusSession

    var body: some View {
        VStack(spacing: 8) {
            if let tomato = session.tomato {
                Image(nsImage: tomato.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 110)
                Text("\(tomato.name) gesammelt!")
                    .font(.headline)
                Text("+\(tomato.points) Pkt")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.red)
            } else {
                Text(session.completed ? "Session geschafft" : "Session beendet")
                    .font(.headline)
            }
            if session.bonusPoints > 0 {
                Text("+\(session.bonusPoints) Bonus für \(session.tasksDone ?? 0) erledigte Aufgaben")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.green)
            }
            Text("\(formatFocus(session.focusedSeconds)) Fokus · \(session.appSwitches) App-Wechsel")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }
}

/// After a completed session with planned tasks: which of them are really done?
/// Only these count, once, and at most `TomatoRules.maxBonusTasks` of them.
@MainActor
struct ReviewView: View {
    @ObservedObject private var model = PomodoroModel.shared
    @State private var done: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session geschafft!")
                .font(.headline)
            Text("Was hast du davon erledigt?")
                .font(.callout)
                .foregroundStyle(Theme.muted)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(model.reviewTasks) { task in
                        Button { toggle(task.id) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: done.contains(task.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(done.contains(task.id) ? Theme.green : Theme.muted)
                                Text(task.title)
                                    .lineLimit(2)
                                Spacer()
                            }
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("+\(TomatoRules.pointsPerTask) Pkt je Aufgabe, höchstens \(TomatoRules.maxBonusTasks) pro Session")
                .font(.caption2)
                .foregroundStyle(Theme.muted)

            HStack {
                TextButton("Nichts davon") { model.review(done: []) }
                Spacer()
                Button { model.review(done: done) } label: {
                    Text("Bestätigen")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.green))
                }
                .buttonStyle(.plain)
                .disabled(done.isEmpty)
                .opacity(done.isEmpty ? 0.4 : 1)
            }

            if model.mode == .rest {
                Text("Pause läuft · \(model.clock)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.green)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func toggle(_ id: UUID) {
        if done.contains(id) { done.remove(id) } else { done.insert(id) }
    }
}

// MARK: - Tasks

@MainActor
struct TasksPage: View {
    @ObservedObject private var tasks = TaskStore.shared
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Für die nächste Session")
                .font(.headline)

            HStack {
                TextField("Neue Aufgabe …", text: $draft)
                    .textFieldStyle(.plain)
                    .onSubmit(add)
                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.red)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).stroke(Theme.hairline))

            if tasks.tasks.isEmpty {
                Text("Noch nichts geplant.")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(tasks.tasks) { TaskRow(task: $0) }
                    }
                }
            }

            if tasks.hasDone {
                TextButton("Erledigte entfernen") { tasks.clearDone() }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func add() {
        tasks.add(draft)
        draft = ""
    }
}

@MainActor
struct TaskRow: View {
    let task: FocusTask
    @ObservedObject private var tasks = TaskStore.shared
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button { tasks.toggle(task.id) } label: {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(task.done ? Theme.green : Theme.muted)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .strikethrough(task.done)
                .foregroundStyle(task.done ? Theme.muted : Theme.ink)
                .lineLimit(2)
            Spacer()
            if hovering {
                Button { tasks.remove(task.id) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .help("Löschen")
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

// MARK: - Collection

@MainActor
struct CollectionPage: View {
    @ObservedObject private var sessions = SessionStore.shared
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Sammlung").font(.headline)
                Spacer()
                Text("\(sessions.totalPoints) Pkt · \(sessions.totalTomatoes) Tomaten")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(TomatoKind.allCases) { kind in
                        TomatoCell(kind: kind, count: sessions.count(of: kind))
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }
}

@MainActor
struct TomatoCell: View {
    let kind: TomatoKind
    let count: Int

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: kind.image)
                    .resizable()
                    .scaledToFit()
                    .saturation(count == 0 ? 0 : 1)
                    .opacity(count == 0 ? 0.25 : 1)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Theme.green))
                }
            }
            Text(kind.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(count > 0 ? Theme.ink : Theme.muted)
                .lineLimit(1)
            Text("\(kind.minutes) min · \(kind.points) Pkt")
                .font(.system(size: 9))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
        .help("Eine Session von mindestens \(kind.minutes) min fokussiert beenden")
    }
}

// MARK: - Shared bits

struct TextButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(Theme.muted)
    }
}

struct IconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// One line in the collapsed floating window: tomato, clock, play/pause, expand.
@MainActor
struct CollapsedBar: View {
    @ObservedObject private var model = PomodoroModel.shared
    @ObservedObject private var panel = FloatingPanelController.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: TomatoArt.image("zen"))
                .resizable()
                .frame(width: 20, height: 20)
            Text(model.clock)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(model.mode == .rest ? Theme.green : (model.isRunning ? Theme.red : Theme.ink))
            Spacer()
            Button { model.toggle() } label: {
                Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Theme.red))
            }
            .buttonStyle(.plain)
            IconButton(systemImage: "chevron.down", help: "Ausklappen") { panel.toggleCollapsed() }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .environment(\.colorScheme, .light)
    }
}
