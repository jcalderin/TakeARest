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

    private func makeSUT(
        intervalMinutes: Int = 20,
        durationSeconds: Int = 20,
        now: Date = Date(timeIntervalSinceReferenceDate: 0)
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

    @Test("Next break is scheduled at now + interval")
    func breakScheduledAtCorrectTime() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (engine, _) = makeSUT(intervalMinutes: 15, now: startTime)
        engine.start()

        let expectedBreak = startTime.addingTimeInterval(15 * 60)
        #expect(engine.nextBreakDate == expectedBreak)
    }

    @Test("Skip next break reschedules from now")
    func skipNextBreak() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (engine, dateHolder) = makeSUT(intervalMinutes: 20, now: startTime)
        engine.start()
        let firstBreakDate = engine.nextBreakDate

        dateHolder.now = startTime.addingTimeInterval(5 * 60)
        engine.skipNextBreak()

        let expectedBreak = dateHolder.now.addingTimeInterval(20 * 60)
        #expect(engine.nextBreakDate == expectedBreak)
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

    @Test("Resume from pause schedules a fresh break")
    func resumeFromPause() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (engine, dateHolder) = makeSUT(intervalMinutes: 20, now: startTime)
        engine.start()
        engine.pause(minutes: nil)
        #expect(engine.isPaused)

        dateHolder.now = startTime.addingTimeInterval(10 * 60)
        engine.resume()

        #expect(engine.isCounting)
        let expectedBreak = dateHolder.now.addingTimeInterval(20 * 60)
        #expect(engine.nextBreakDate == expectedBreak)
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

    @Test("After wake past break time, break is rescheduled with grace period")
    func wakeGracePeriod() {
        let startTime = Date(timeIntervalSinceReferenceDate: 1000)
        let (engine, dateHolder) = makeSUT(intervalMinutes: 20, now: startTime)
        engine.start()
        let originalBreakDate = engine.nextBreakDate!

        dateHolder.now = startTime.addingTimeInterval(30 * 60)
        engine.handleSystemWake()

        #expect(engine.isCounting)
        if let newBreakDate = engine.nextBreakDate {
            let gracePeriod = newBreakDate.timeIntervalSince(dateHolder.now)
            #expect(newBreakDate > originalBreakDate)
            #expect(gracePeriod > 0 && gracePeriod <= 3.0)
        } else {
            Issue.record("Expected nextBreakDate to be set")
        }
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
}

// MARK: - Test Helper

@MainActor
final class CurrentDateHolder {
    var now: Date

    init(_ date: Date) {
        self.now = date
    }
}
