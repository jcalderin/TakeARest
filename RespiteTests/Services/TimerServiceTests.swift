import AppKit
import Foundation
import Testing
@testable import Respite

/// Tests for TimerEngine (formerly TimerService).
///
/// Uses an injectable `dateProvider` to control time without waiting.
/// Each test creates an isolated BreakTimer config.
@Suite("TimerEngine")
@MainActor
struct TimerEngineTests {

    /// A clock time on a fixed reference day, in the local calendar.
    private static func clockDate(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour, minute: minute, second: 0,
            of: Date(timeIntervalSinceReferenceDate: 0)
        )!
    }

    private func makeSUT(
        intervalMinutes: Int = 20,
        durationSeconds: Int = 20,
        now: Date = TimerEngineTests.clockDate(9, 0) // a clean grid slot
    ) -> (TimerEngine, CurrentDateHolder) {
        let timer = BreakTimer(
            id: UUID(),
            name: "Test Timer",
            isEnabled: true,
            breakIntervalMinutes: intervalMinutes,
            breakDurationSeconds: durationSeconds,
            overlayColorHex: "#000000",
            overlayOpacity: 0.85,
            breakMessage: "Test break",
            dimAnimationDuration: 5.0,
            showCountdown: true,
            playSoundOnBreak: false,
            activeDays: [1, 2, 3, 4, 5, 6, 7],
            startHour: 0,
            startMinute: 0,
            endHour: 23,
            endMinute: 59
        )

        let dateHolder = CurrentDateHolder(now)
        let engine = TimerEngine(breakTimer: timer, dateProvider: { dateHolder.now })
        return (engine, dateHolder)
    }

    // MARK: - State Machine

    @Test("Engine starts in idle state")
    func initialState() {
        let (engine, _) = makeSUT()
        #expect(engine.state == .idle)
        #expect(!engine.isCounting)
        #expect(!engine.isOnBreak)
        #expect(!engine.isPaused)
    }

    @Test("Start transitions from idle to counting")
    func startTransition() {
        let (engine, _) = makeSUT()
        engine.start()
        #expect(engine.state == .counting)
        #expect(engine.isCounting)
        #expect(engine.nextBreakDate != nil)
    }

    @Test("Start is ignored if already counting")
    func startWhenAlreadyCounting() {
        let (engine, _) = makeSUT()
        engine.start()
        let firstBreakDate = engine.nextBreakDate
        engine.start()
        #expect(engine.nextBreakDate == firstBreakDate)
    }

    @Test("Stop returns to idle")
    func stopTransition() {
        let (engine, _) = makeSUT()
        engine.start()
        engine.stop()
        #expect(engine.state == .idle)
        #expect(engine.nextBreakDate == nil)
        #expect(engine.secondsUntilBreak == 0)
    }

    // MARK: - Break Scheduling

    @Test("Next break is scheduled at the next clock slot")
    func breakScheduledAtCorrectTime() {
        // Default now is 09:00 (a grid slot), so a 15-min interval lands at 09:15.
        let (engine, _) = makeSUT(intervalMinutes: 15)
        engine.start()
        #expect(engine.nextBreakDate == dateAt(9, 15))
    }

    @Test("Skip next break advances past the upcoming slot")
    func skipNextBreak() {
        let (engine, dateHolder) = makeSUT(intervalMinutes: 20)
        engine.start()
        let firstBreakDate = engine.nextBreakDate // 09:20

        dateHolder.now = dateAt(9, 5)
        engine.skipNextBreak()

        // Skips the 09:20 slot, lands on the next one.
        #expect(engine.nextBreakDate == dateAt(9, 40))
        #expect(engine.nextBreakDate != firstBreakDate)
    }

    @Test("Take break now triggers immediately")
    func takeBreakNow() {
        let (engine, _) = makeSUT()
        engine.start()
        #expect(engine.isCounting)

        var breakFired = false
        engine.onBreakStarted = { _ in breakFired = true }
        engine.takeBreakNow()

        #expect(engine.isOnBreak)
        #expect(breakFired)
    }

    // MARK: - Break Lifecycle

    @Test("Skip current break ends break and reschedules")
    func skipCurrentBreak() {
        let (engine, _) = makeSUT()
        engine.start()

        var breakEnded = false
        engine.onBreakEnded = { _ in breakEnded = true }
        engine.takeBreakNow()
        #expect(engine.isOnBreak)

        engine.skipCurrentBreak()
        #expect(engine.isCounting)
        #expect(breakEnded)
        #expect(engine.nextBreakDate != nil)
    }

    @Test("Postpone break reschedules to now + postpone duration")
    func postponeBreak() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (engine, dateHolder) = makeSUT(now: startTime)

        engine.start()
        engine.takeBreakNow()
        #expect(engine.isOnBreak)

        var breakEnded = false
        engine.onBreakEnded = { _ in breakEnded = true }
        engine.postponeBreak(minutes: 5)

        #expect(engine.isCounting)
        #expect(breakEnded)
        let expectedBreak = dateHolder.now.addingTimeInterval(5 * 60)
        #expect(engine.nextBreakDate == expectedBreak)
    }

    // MARK: - Pause

    @Test("Pause transitions from counting to paused")
    func pauseTransition() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (engine, _) = makeSUT(now: startTime)
        engine.start()

        engine.pause(minutes: 30)
        #expect(engine.isPaused)
        if case .paused(let until) = engine.state {
            #expect(until == startTime.addingTimeInterval(30 * 60))
        } else {
            Issue.record("Expected paused state")
        }
    }

    @Test("Indefinite pause has no resume date")
    func indefinitePause() {
        let (engine, _) = makeSUT()
        engine.start()
        engine.pause(minutes: nil)

        if case .paused(let until) = engine.state {
            #expect(until == nil)
        } else {
            Issue.record("Expected paused state")
        }
    }

    @Test("Resume from pause schedules onto the next clock slot")
    func resumeFromPause() {
        let (engine, dateHolder) = makeSUT(intervalMinutes: 20)
        engine.start()
        engine.pause(minutes: nil)
        #expect(engine.isPaused)

        dateHolder.now = dateAt(9, 10)
        engine.resume()

        #expect(engine.isCounting)
        #expect(engine.nextBreakDate == dateAt(9, 20))
    }

    // MARK: - Invalid Transitions

    @Test("Cannot pause while on break")
    func cannotPauseOnBreak() {
        let (engine, _) = makeSUT()
        engine.start()
        engine.takeBreakNow()
        #expect(engine.isOnBreak)

        engine.pause(minutes: 15)
        #expect(engine.isOnBreak)
    }

    @Test("Cannot skip next break while on break")
    func cannotSkipNextWhileOnBreak() {
        let (engine, _) = makeSUT()
        engine.start()
        engine.takeBreakNow()

        engine.skipNextBreak()
        #expect(engine.isOnBreak)
    }

    @Test("Cannot take break now while paused")
    func cannotBreakWhilePaused() {
        let (engine, _) = makeSUT()
        engine.start()
        engine.pause(minutes: 15)

        engine.takeBreakNow()
        #expect(engine.isPaused)
    }

    // MARK: - Postpone Limits

    @Test("Postpone count increments and blocks after max")
    func postponeLimitEnforced() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (engine, _) = makeSUT(now: startTime)
        engine.start()

        for i in 1...TimerEngine.maxPostponesPerCycle {
            engine.takeBreakNow()
            #expect(engine.isOnBreak)
            #expect(engine.canPostpone)
            engine.postponeBreak(minutes: 5)
            #expect(engine.postponeCount == i)
        }

        engine.takeBreakNow()
        #expect(engine.isOnBreak)
        #expect(!engine.canPostpone)
        engine.postponeBreak(minutes: 5)
        #expect(engine.isOnBreak)
        #expect(engine.postponeCount == TimerEngine.maxPostponesPerCycle)
    }

    @Test("Postpone count resets on new break cycle")
    func postponeCountResetsOnNewCycle() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (engine, _) = makeSUT(now: startTime)
        engine.start()

        engine.takeBreakNow()
        engine.postponeBreak(minutes: 5)
        #expect(engine.postponeCount == 1)

        engine.takeBreakNow()
        engine.skipCurrentBreak()

        #expect(engine.postponeCount == 0)
        #expect(engine.canPostpone)
    }

    @Test("Skip button always works regardless of postpone count")
    func skipAlwaysAvailable() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (engine, _) = makeSUT(now: startTime)
        engine.start()

        for _ in 1...TimerEngine.maxPostponesPerCycle {
            engine.takeBreakNow()
            engine.postponeBreak(minutes: 5)
        }

        engine.takeBreakNow()
        #expect(!engine.canPostpone)
        engine.skipCurrentBreak()
        #expect(engine.isCounting)
    }

    // MARK: - Sleep/Wake Simulation

    @Test("After waking past a slot, snaps to the next clock slot")
    func wakeSnapsToGrid() {
        let (engine, dateHolder) = makeSUT(intervalMinutes: 20)
        engine.start() // next 09:20

        dateHolder.now = dateAt(9, 50) // slept through 09:20 and 09:40
        engine.handleSystemWake()

        #expect(engine.isCounting)
        #expect(engine.nextBreakDate == dateAt(10, 0))
    }

    @Test("Timed pause resumes if wake occurs past its resume time")
    func wakeResumesExpiredPause() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (engine, dateHolder) = makeSUT(intervalMinutes: 20, now: startTime)
        engine.start()
        engine.pause(minutes: 30)
        #expect(engine.isPaused)

        // Slept past the resume time, then woke.
        dateHolder.now = startTime.addingTimeInterval(31 * 60)
        engine.handleSystemWake()

        #expect(engine.isCounting)
    }

    @Test("Break interrupted by sleep ends on wake")
    func wakeEndsExpiredBreak() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (engine, dateHolder) = makeSUT(durationSeconds: 20, now: startTime)
        engine.start()
        engine.takeBreakNow()
        #expect(engine.isOnBreak)

        // Slept past the break end, then woke.
        dateHolder.now = startTime.addingTimeInterval(60)
        engine.handleSystemWake()

        #expect(engine.isCounting)
    }

    // MARK: - Clock Anchor & Skip-Once

    private func makeAnchoredSUT(
        intervalMinutes: Int, anchorMinute: Int, now: Date
    ) -> (TimerEngine, CurrentDateHolder) {
        var timer = BreakTimer(
            id: UUID(), name: "Anchored", isEnabled: true,
            breakIntervalMinutes: intervalMinutes, breakDurationSeconds: 20,
            overlayColorHex: "#000000", overlayOpacity: 0.85, breakMessage: "x",
            dimAnimationDuration: 5.0, showCountdown: true, playSoundOnBreak: false,
            activeDays: [1, 2, 3, 4, 5, 6, 7], startHour: 0, startMinute: 0,
            endHour: 23, endMinute: 59
        )
        timer.alignMinute = anchorMinute
        let holder = CurrentDateHolder(now)
        let engine = TimerEngine(breakTimer: timer, dateProvider: { holder.now })
        return (engine, holder)
    }

    private func dateAt(_ hour: Int, _ minute: Int) -> Date {
        Self.clockDate(hour, minute)
    }

    @Test("Anchored timer fires at the next clock slot")
    func anchoredNextSlot() {
        let (engine, _) = makeAnchoredSUT(intervalMinutes: 20, anchorMinute: 0, now: dateAt(10, 15))
        engine.start()
        #expect(engine.nextBreakDate == dateAt(10, 20))
    }

    @Test("Align offset shifts the grid so a slot lands before the hour")
    func alignOffsetShiftsGrid() {
        // Every 20 min, aligned to :55 → slots :15 / :35 / :55.
        let (engine, _) = makeAnchoredSUT(intervalMinutes: 20, anchorMinute: 55, now: dateAt(10, 0))
        engine.start()
        #expect(engine.nextBreakDate == dateAt(10, 15))
    }

    @Test("Align offset lands a slot at :55 to finish before the hour")
    func alignOffsetLandsAtFiftyFive() {
        let (engine, _) = makeAnchoredSUT(intervalMinutes: 20, anchorMinute: 55, now: dateAt(10, 40))
        engine.start()
        #expect(engine.nextBreakDate == dateAt(10, 55))
    }

    @Test("Anchored interval that doesn't divide 60 still steps on grid")
    func anchoredNonDivisorInterval() {
        // 25-min interval, anchor 0 → slots :00, :25, :50, …
        let (engine, _) = makeAnchoredSUT(intervalMinutes: 25, anchorMinute: 0, now: dateAt(0, 10))
        engine.start()
        #expect(engine.nextBreakDate == dateAt(0, 25))
    }

    @Test("Skip-once on an anchored timer advances to the next grid slot")
    func skipOnceAnchoredKeepsGrid() {
        let (engine, holder) = makeAnchoredSUT(intervalMinutes: 20, anchorMinute: 0, now: dateAt(9, 59))
        engine.start()
        #expect(engine.nextBreakDate == dateAt(10, 0))

        holder.now = dateAt(10, 0)
        engine.skipScheduledOccurrence()
        #expect(engine.nextBreakDate == dateAt(10, 20))
    }

    @Test("Skip-once stays on the grid even when called late")
    func skipOnceStaysOnGrid() {
        let (engine, holder) = makeAnchoredSUT(intervalMinutes: 20, anchorMinute: 0, now: dateAt(9, 0))
        engine.start()
        let scheduled = engine.nextBreakDate!     // 09:20

        // Suppression happens slightly after the scheduled fire.
        holder.now = scheduled.addingTimeInterval(5)
        engine.skipScheduledOccurrence()

        // Advances to the next grid slot (09:40), not now + interval.
        #expect(engine.nextBreakDate == dateAt(9, 40))
        #expect(engine.isCounting)
    }

    @Test("Skip-once fires no callbacks")
    func skipOnceFiresNoCallbacks() {
        let (engine, _) = makeSUT()
        engine.start()
        var started = false
        var ended = false
        engine.onBreakStarted = { _ in started = true }
        engine.onBreakEnded = { _ in ended = true }

        engine.skipScheduledOccurrence()
        #expect(!started)
        #expect(!ended)
    }

    @Test("Anchored timer snaps to next slot after waking past a slot")
    func anchoredWakeSnapsToGrid() {
        let (engine, holder) = makeAnchoredSUT(intervalMinutes: 20, anchorMinute: 0, now: dateAt(9, 50))
        engine.start()
        #expect(engine.nextBreakDate == dateAt(10, 0))

        // Slept through 10:00 and 10:20, woke at 10:35.
        holder.now = dateAt(10, 35)
        engine.handleSystemWake()
        #expect(engine.nextBreakDate == dateAt(10, 40))
    }

    // MARK: - Pre-Warning

    /// An engine whose next slot is `secondsBefore` away, with a lead window
    /// wide enough to cover it.
    private func makePreWarnSUT(
        style: PreWarnStyle, leadSeconds: Int, now: Date
    ) -> (TimerEngine, CurrentDateHolder) {
        let (engine, holder) = makeAnchoredSUT(intervalMinutes: 20, anchorMinute: 0, now: now)
        var cfg = engine.breakTimer
        cfg.preWarnStyle = style
        cfg.preWarnSeconds = leadSeconds
        engine.updateConfiguration(cfg) // engine is idle here, just stores config
        return (engine, holder)
    }

    @Test("Pre-warn fires once when the countdown enters the lead window")
    func preWarnFiresOnce() {
        // 09:19 → next slot 09:20 (60s away), lead 120s covers it.
        let (engine, holder) = makePreWarnSUT(style: .pill, leadSeconds: 120, now: dateAt(9, 19))
        var count = 0
        engine.onPreWarn = { _, _ in count += 1 }

        engine.start()           // first tick: 60s ≤ 120 → fires
        #expect(count == 1)

        engine.handleSystemWake() // forces another tick; must not re-fire
        #expect(count == 1)
    }

    @Test("Pre-warn does not fire when style is off")
    func preWarnOffDoesNotFire() {
        let (engine, _) = makePreWarnSUT(style: .off, leadSeconds: 120, now: dateAt(9, 19))
        var count = 0
        engine.onPreWarn = { _, _ in count += 1 }
        engine.start()
        #expect(count == 0)
    }

    @Test("Pre-warn is cancelled when paused mid-warning")
    func preWarnCancelOnPause() {
        let (engine, _) = makePreWarnSUT(style: .pill, leadSeconds: 120, now: dateAt(9, 19))
        var warned = false
        var cancelled = false
        engine.onPreWarn = { _, _ in warned = true }
        engine.onPreWarnCancel = { cancelled = true }

        engine.start()
        #expect(warned)

        engine.pause(minutes: nil)
        #expect(cancelled)
    }

    @Test("startTest runs a quick cycle and fires the heads-up")
    func startTestFiresPreWarn() {
        let (engine, _) = makePreWarnSUT(style: .pill, leadSeconds: 30, now: dateAt(9, 0))
        var warned = false
        engine.onPreWarn = { _, _ in warned = true }

        engine.startTest()
        #expect(engine.isCounting)
        #expect(warned) // lead capped to 8s ≤ 30 → fires on the first tick
    }

    @Test("startTest with heads-up off goes straight to the break")
    func startTestOffStartsBreak() {
        let (engine, _) = makePreWarnSUT(style: .off, leadSeconds: 30, now: dateAt(9, 0))
        var warned = false
        var broke = false
        engine.onPreWarn = { _, _ in warned = true }
        engine.onBreakStarted = { _ in broke = true }

        engine.startTest()
        #expect(!warned)
        #expect(broke)
        #expect(engine.isOnBreak)
    }

    // MARK: - Countdown Formatting

    @Test("Countdown formatted string is correct")
    func countdownFormatting() {
        let (engine, _) = makeSUT(intervalMinutes: 20)
        engine.start()
        #expect(engine.secondsUntilBreak == 20 * 60)
        #expect(engine.countdownFormatted == "20:00")
    }

    // MARK: - Configuration Update

    @Test("Update configuration changes break timer")
    func updateConfiguration() {
        let (engine, _) = makeSUT(intervalMinutes: 20)
        engine.start()

        var newConfig = engine.breakTimer
        newConfig.breakIntervalMinutes = 30
        newConfig.breakMessage = "New message"
        engine.updateConfiguration(newConfig)

        #expect(engine.breakTimer.breakIntervalMinutes == 30)
        #expect(engine.breakTimer.breakMessage == "New message")
    }

    @Test("Changing align minute while counting reschedules onto the new grid")
    func changingAlignReschedules() {
        let (engine, _) = makeAnchoredSUT(intervalMinutes: 60, anchorMinute: 0, now: dateAt(12, 28))
        engine.start()
        #expect(engine.nextBreakDate == dateAt(13, 0)) // hourly on the hour

        var updated = engine.breakTimer
        updated.alignMinute = 30
        engine.updateConfiguration(updated)

        // Re-aligns to :30 → next slot is 12:30.
        #expect(engine.nextBreakDate == dateAt(12, 30))
    }
}

// MARK: - Test Helper

@MainActor
final class CurrentDateHolder {
    var now: Date

    init(_ date: Date) {
        self.now = date
    }
}

// MARK: - TimerManager Coverage

/// Tests the "covered by" supersede behavior in TimerManager.
@Suite("TimerManager coverage")
@MainActor
struct TimerManagerCoverageTests {

    private func makeTimer(
        name: String, interval: Int, enabled: Bool = true, coveredBy: Set<UUID> = []
    ) -> BreakTimer {
        var timer = BreakTimer(
            id: UUID(), name: name, isEnabled: enabled,
            breakIntervalMinutes: interval, breakDurationSeconds: 20,
            overlayColorHex: "#000000", overlayOpacity: 0.85, breakMessage: "x",
            dimAnimationDuration: 5.0, showCountdown: true, playSoundOnBreak: false,
            activeDays: [1, 2, 3, 4, 5, 6, 7], startHour: 0, startMinute: 0,
            endHour: 23, endMinute: 59
        )
        timer.coveredByTimerIDs = coveredBy
        return timer
    }

    private func makeManager(_ timers: [BreakTimer]) -> (TimerManager, [UUID]) {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults)
        settings.timers = timers
        let manager = TimerManager(settings: settings)
        manager.syncEngines()
        return (manager, timers.map(\.id))
    }

    @Test("Covered break is suppressed while the covering timer is on break")
    func suppressedWhileCoveringOnBreak() {
        let covering = makeTimer(name: "Stand", interval: 60)
        let covered = makeTimer(name: "Look", interval: 20, coveredBy: [covering.id])
        let (manager, _) = makeManager([covering, covered])

        var shown: [UUID] = []
        manager.onBreakStarted = { timer, _ in shown.append(timer.id) }

        manager.engines[covering.id]!.takeBreakNow()   // covering fires first
        manager.engines[covered.id]!.takeBreakNow()    // covered coincides

        #expect(shown == [covering.id])                // only the covering break shows
        #expect(manager.activeBreak?.id == covering.id)
        #expect(manager.engines[covered.id]!.isCounting) // covered skipped → counting
    }

    @Test("No suppression when the covering timer is idle")
    func noSuppressionWhenCoveringIdle() {
        // Covering disabled → its engine stays idle, so it can't suppress.
        let covering = makeTimer(name: "Stand", interval: 60, enabled: false)
        let covered = makeTimer(name: "Look", interval: 20, coveredBy: [covering.id])
        let (manager, _) = makeManager([covering, covered])

        var shown: [UUID] = []
        manager.onBreakStarted = { timer, _ in shown.append(timer.id) }

        manager.engines[covered.id]!.takeBreakNow()

        #expect(shown == [covered.id])                 // covered shows normally
        #expect(manager.activeBreak?.id == covered.id)
    }
}
