import AppKit
import Combine
import Foundation

/// Orchestrates multiple `TimerEngine` instances — one per `BreakTimer`.
///
/// Responsibilities:
/// - Create/destroy engines to match `AppSettings.timers`
/// - Evaluate schedules every 60s (start/stop engines based on cron)
/// - Queue overlays when multiple timers fire simultaneously (FIFO)
/// - Provide pause-all / resume-all for "interview mode"
@MainActor
@Observable
final class TimerManager {

    // MARK: - State

    /// All engines, keyed by BreakTimer.id.
    private(set) var engines: [UUID: TimerEngine] = [:]

    /// The timer currently showing its break overlay, if any.
    private(set) var activeBreak: BreakTimer?

    /// The engine currently on break, if any.
    private(set) var activeBreakEngine: TimerEngine?

    /// Queued breaks waiting for the current break to end.
    private var breakQueue: [(engine: TimerEngine, timer: BreakTimer)] = []

    /// Callback fired when a break should show its overlay.
    var onBreakStarted: ((BreakTimer, TimerEngine) -> Void)?

    /// Callback fired when the current break overlay should dismiss.
    var onBreakEnded: (() -> Void)?

    /// Callback fired when a heads-up should be shown for an imminent break.
    var onPreWarn: ((BreakTimer, TimerEngine) -> Void)?

    /// Callback fired when an active heads-up should be taken down.
    var onPreWarnCancel: (() -> Void)?

    // MARK: - Dependencies

    private let settings: AppSettings
    private let dateProvider: () -> Date

    // MARK: - Internal

    private var scheduleTimer: AnyCancellable?

    // MARK: - Init

    init(settings: AppSettings, dateProvider: @escaping () -> Date = { Date() }) {
        self.settings = settings
        self.dateProvider = dateProvider
    }

    // MARK: - Public API

    /// Synchronize engines with the current timers array in settings.
    /// Call after init, and whenever settings.timers changes.
    func syncEngines() {
        let currentTimers = settings.timers
        let currentIDs = Set(currentTimers.map(\.id))
        let existingIDs = Set(engines.keys)

        // Remove engines for deleted timers
        for id in existingIDs.subtracting(currentIDs) {
            engines[id]?.stop()
            engines.removeValue(forKey: id)
        }

        // Add or update engines for current timers
        for timer in currentTimers {
            if let engine = engines[timer.id] {
                engine.updateConfiguration(timer)
            } else {
                let engine = TimerEngine(breakTimer: timer, dateProvider: dateProvider)
                wireEngine(engine)
                engines[timer.id] = engine
            }
        }

        // Evaluate schedules to start/stop as needed
        evaluateSchedules()
        startScheduleEvaluation()
    }

    /// Evaluate all timer schedules against the current date/time.
    /// Starts engines that should be active, stops those that shouldn't.
    func evaluateSchedules() {
        let now = dateProvider()

        for (_, engine) in engines {
            let shouldBeActive = engine.breakTimer.isScheduledActive(at: now)

            if shouldBeActive && engine.isIdle {
                engine.start()
            } else if !shouldBeActive && !engine.isIdle && !engine.isOnBreak {
                // Don't interrupt an active break, but stop counting/paused engines
                engine.stop()
            }
        }
    }

    /// Run a one-off test preview (heads-up + break) for a timer, on its engine.
    func runTest(for id: UUID) {
        engines[id]?.startTest()
    }

    /// Pause all active engines for the given duration.
    /// Pass `nil` for indefinite pause ("Until I Resume").
    func pauseAll(minutes: Int?) {
        for (_, engine) in engines where engine.isCounting {
            engine.pause(minutes: minutes)
        }
    }

    /// Resume all paused engines.
    func resumeAll() {
        for (_, engine) in engines where engine.isPaused {
            engine.resume()
        }
    }

    // MARK: - Computed: Engine Lists

    /// Engines that are currently active (counting, on break, or paused).
    var activeEngines: [TimerEngine] {
        engines.values
            .filter { !$0.isIdle }
            .sorted { $0.breakTimer.name < $1.breakTimer.name }
    }

    /// Engines that are idle (disabled or outside their schedule window).
    var inactiveEngines: [TimerEngine] {
        engines.values
            .filter { $0.isIdle }
            .sorted { $0.breakTimer.name < $1.breakTimer.name }
    }

    /// All engines sorted by name.
    var allEngines: [TimerEngine] {
        engines.values.sorted { $0.breakTimer.name < $1.breakTimer.name }
    }

    /// Whether any engine is currently paused.
    var hasAnyPaused: Bool {
        engines.values.contains { $0.isPaused }
    }

    /// Whether any engine is currently counting.
    var hasAnyCounting: Bool {
        engines.values.contains { $0.isCounting }
    }

    // MARK: - Private: Engine Wiring

    private func wireEngine(_ engine: TimerEngine) {
        engine.onBreakStarted = { [weak self] timer in
            self?.handleBreakStarted(from: engine, timer: timer)
        }
        engine.onBreakEnded = { [weak self] timer in
            self?.handleBreakEnded(from: engine, timer: timer)
        }
        engine.onPreWarn = { [weak self] timer, engine in
            self?.onPreWarn?(timer, engine)
        }
        engine.onPreWarnCancel = { [weak self] in
            self?.onPreWarnCancel?()
        }
    }

    private func handleBreakStarted(from engine: TimerEngine, timer: BreakTimer) {
        // Supersede: if a timer that covers this one is firing coincidentally,
        // skip this break once (keep its schedule) — don't show or queue it.
        if isSuperseded(timer, now: dateProvider()) {
            engine.skipScheduledOccurrence()
            return
        }

        if activeBreak != nil {
            // Already showing a break — queue this one
            breakQueue.append((engine: engine, timer: timer))
        } else {
            // Show this break's overlay
            activeBreak = timer
            activeBreakEngine = engine
            onBreakStarted?(timer, engine)
        }
    }

    /// Whether `timer`'s just-started break should be suppressed because a timer
    /// that covers it is firing coincidentally.
    ///
    /// Handles both tick orderings (each engine has an independent 1s timer):
    /// the covering timer may already be on break (it fired first), or still
    /// counting but due within the coincidence window (it fires momentarily).
    /// A missing or idle covering engine (deleted, disabled, out of schedule)
    /// is not coincident, so it never suppresses.
    private func isSuperseded(_ timer: BreakTimer, now: Date) -> Bool {
        guard !timer.coveredByTimerIDs.isEmpty else { return false }
        for coveringID in timer.coveredByTimerIDs {
            guard let covering = engines[coveringID] else { continue }
            if covering.isOnBreak { return true }
            if covering.isCounting, let due = covering.nextBreakDate,
               abs(due.timeIntervalSince(now)) <= DesignTokens.coverageCoincidenceWindow {
                return true
            }
        }
        return false
    }

    private func handleBreakEnded(from engine: TimerEngine, timer: BreakTimer) {
        // If this was the active break, dismiss and check queue
        if activeBreak?.id == timer.id {
            activeBreak = nil
            activeBreakEngine = nil
            onBreakEnded?()

            // Show the next still-valid queued break. A queued break may have
            // ended naturally (now counting) or become superseded while waiting
            // (a covering timer started) — skip those and keep draining.
            while let next = breakQueue.first {
                breakQueue.removeFirst()
                guard next.engine.isOnBreak else { continue }
                if isSuperseded(next.timer, now: dateProvider()) {
                    next.engine.skipScheduledOccurrence()
                    continue
                }
                activeBreak = next.timer
                activeBreakEngine = next.engine
                onBreakStarted?(next.timer, next.engine)
                break
            }
        }
    }

    // MARK: - Private: Schedule Evaluation Timer

    private func startScheduleEvaluation() {
        scheduleTimer?.cancel()
        scheduleTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.evaluateSchedules()
            }
    }
}
