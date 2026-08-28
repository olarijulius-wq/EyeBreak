import AppKit

final class BreakScheduler: NSObject {
    static let supportedIntervalMinutes = [15, 20, 30, 45, 60]
    static let defaultIntervalMinutes = 20
    static let breakIntervalDefaultsKey = "breakIntervalMinutes"
    static let snoozeUntilDefaultsKey = "snoozeUntil"
    static let adaptiveTimingDefaultsKey = "adaptiveTimingEnabled"

    private static let activitySampleInterval: TimeInterval = 30
    private static let idleGapThreshold: TimeInterval = 60
    private static let adaptiveAdvance: TimeInterval = 2 * 60

    private let calendar: Calendar
    private let userDefaults: UserDefaults
    private let onPreWarning: () -> Void
    private let onBreak: () -> Void
    private let shouldSuppressBreak: () -> Bool
    private let onBreakSkipped: () -> Void
    private let onSnoozeEnded: () -> Void
    private var preWarningTimer: Timer?
    private var timer: Timer?
    private var adaptivePreWarningTimer: Timer?
    private var adaptiveBreakTimer: Timer?
    private var activitySampleTimer: Timer?
    private var snoozeEndTimer: Timer?
    private var regularFireDate: Date?
    private var activityTrackingStartDate: Date?
    private var lastObservedInputDate: Date?
    private var snoozeUntil: Date?
    private var observedIdleGap = false
    private(set) var isPaused = false
    private(set) var intervalMinutes: Int
    private(set) var adaptiveTimingEnabled: Bool
    private(set) var nextFireDate: Date?

    init(
        calendar: Calendar = .autoupdatingCurrent,
        userDefaults: UserDefaults = .standard,
        onPreWarning: @escaping () -> Void,
        onBreak: @escaping () -> Void,
        shouldSuppressBreak: @escaping () -> Bool = { false },
        onBreakSkipped: @escaping () -> Void = {},
        onSnoozeEnded: @escaping () -> Void = {}
    ) {
        self.calendar = calendar
        self.userDefaults = userDefaults
        self.onPreWarning = onPreWarning
        self.onBreak = onBreak
        self.shouldSuppressBreak = shouldSuppressBreak
        self.onBreakSkipped = onBreakSkipped
        self.onSnoozeEnded = onSnoozeEnded

        let savedInterval = userDefaults.integer(forKey: Self.breakIntervalDefaultsKey)
        intervalMinutes = Self.supportedIntervalMinutes.contains(savedInterval)
            ? savedInterval
            : Self.defaultIntervalMinutes
        adaptiveTimingEnabled = userDefaults.object(
            forKey: Self.adaptiveTimingDefaultsKey
        ) as? Bool ?? false

        if let savedSnoozeUntil = userDefaults.object(
            forKey: Self.snoozeUntilDefaultsKey
        ) as? Date, savedSnoozeUntil > Date() {
            snoozeUntil = savedSnoozeUntil
        } else {
            snoozeUntil = nil
            userDefaults.removeObject(forKey: Self.snoozeUntilDefaultsKey)
        }

        super.init()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    deinit {
        invalidateScheduledTimers()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func start() {
        isPaused = false
        scheduleNextBoundary()
    }

    func stop() {
        invalidateScheduledTimers()
        regularFireDate = nil
        nextFireDate = nil
    }

    @discardableResult
    func togglePaused() -> Bool {
        isPaused.toggle()

        if isPaused {
            stop()
        } else {
            scheduleNextBoundary()
        }

        return isPaused
    }

    func setIntervalMinutes(_ minutes: Int) {
        guard Self.supportedIntervalMinutes.contains(minutes) else {
            return
        }

        let intervalChanged = minutes != intervalMinutes
        intervalMinutes = minutes
        userDefaults.set(minutes, forKey: Self.breakIntervalDefaultsKey)

        if intervalChanged, !isPaused {
            scheduleNextBoundary()
        }
    }

    func setAdaptiveTimingEnabled(_ isEnabled: Bool) {
        guard adaptiveTimingEnabled != isEnabled else {
            return
        }

        adaptiveTimingEnabled = isEnabled
        userDefaults.set(isEnabled, forKey: Self.adaptiveTimingDefaultsKey)

        if !isPaused {
            scheduleNextBoundary()
        }
    }

    func reschedule() {
        guard !isPaused else {
            return
        }

        scheduleNextBoundary()
    }

    func setImportedSnoozeUntil(_ date: Date) {
        guard date > Date() else {
            snoozeUntil = nil
            userDefaults.removeObject(forKey: Self.snoozeUntilDefaultsKey)
            return
        }

        snoozeUntil = date
        userDefaults.set(date, forKey: Self.snoozeUntilDefaultsKey)
    }

    func snooze(for duration: TimeInterval) {
        let endDate = Date().addingTimeInterval(max(0, duration))
        snoozeUntil = endDate
        userDefaults.set(endDate, forKey: Self.snoozeUntilDefaultsKey)

        if !isPaused {
            scheduleNextBoundary()
        }
    }

    func activeSnoozeUntil(at date: Date = Date()) -> Date? {
        guard let snoozeUntil else {
            return nil
        }

        guard snoozeUntil <= date else {
            return snoozeUntil
        }

        self.snoozeUntil = nil
        userDefaults.removeObject(forKey: Self.snoozeUntilDefaultsKey)
        return nil
    }

    private func scheduleNextBoundary(after date: Date = Date()) {
        invalidateScheduledTimers()
        regularFireDate = nil
        nextFireDate = nil
        observedIdleGap = false

        guard !isPaused else {
            return
        }

        if let snoozeUntil = activeSnoozeUntil(at: date) {
            scheduleSnoozeEnd(at: snoozeUntil)
            return
        }

        guard
            let fireDate = Self.nextBoundary(
                after: date,
                intervalMinutes: intervalMinutes,
                calendar: calendar
            )
        else {
            return
        }

        let newTimer = Timer(
            fireAt: fireDate,
            interval: 0,
            target: self,
            selector: #selector(timerFired(_:)),
            userInfo: nil,
            repeats: false
        )
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
        regularFireDate = fireDate
        nextFireDate = fireDate

        let preWarningDate = fireDate.addingTimeInterval(-5)

        if preWarningDate > date {
            let newPreWarningTimer = Timer(
                fireAt: preWarningDate,
                interval: 0,
                target: self,
                selector: #selector(preWarningTimerFired(_:)),
                userInfo: nil,
                repeats: false
            )
            RunLoop.main.add(newPreWarningTimer, forMode: .common)
            preWarningTimer = newPreWarningTimer
        }

        scheduleAdaptiveTimers(for: fireDate, after: date)
    }

    private func scheduleSnoozeEnd(at endDate: Date) {
        let newTimer = Timer(
            fireAt: endDate,
            interval: 0,
            target: self,
            selector: #selector(snoozeEndTimerFired(_:)),
            userInfo: nil,
            repeats: false
        )
        RunLoop.main.add(newTimer, forMode: .common)
        snoozeEndTimer = newTimer
        nextFireDate = endDate
    }

    private func scheduleAdaptiveTimers(for fireDate: Date, after date: Date) {
        guard adaptiveTimingEnabled else {
            return
        }

        let fullInterval = TimeInterval(intervalMinutes * 60)
        guard fireDate.timeIntervalSince(date) >= fullInterval - 1 else {
            return
        }

        let adaptiveFireDate = fireDate.addingTimeInterval(-Self.adaptiveAdvance)
        guard adaptiveFireDate > date else {
            return
        }

        let trackingStartDate = Date()
        activityTrackingStartDate = trackingStartDate
        lastObservedInputDate = trackingStartDate
        sampleActivity()
        guard !observedIdleGap else {
            return
        }

        let newAdaptiveTimer = Timer(
            fireAt: adaptiveFireDate,
            interval: 0,
            target: self,
            selector: #selector(adaptiveBreakTimerFired(_:)),
            userInfo: nil,
            repeats: false
        )
        RunLoop.main.add(newAdaptiveTimer, forMode: .common)
        adaptiveBreakTimer = newAdaptiveTimer
        nextFireDate = adaptiveFireDate

        let preWarningDate = adaptiveFireDate.addingTimeInterval(-5)

        if preWarningDate > date {
            let newPreWarningTimer = Timer(
                fireAt: preWarningDate,
                interval: 0,
                target: self,
                selector: #selector(adaptivePreWarningTimerFired(_:)),
                userInfo: nil,
                repeats: false
            )
            RunLoop.main.add(newPreWarningTimer, forMode: .common)
            adaptivePreWarningTimer = newPreWarningTimer
        }

        let sampleTimer = Timer(
            timeInterval: Self.activitySampleInterval,
            target: self,
            selector: #selector(activitySampleTimerFired(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(sampleTimer, forMode: .common)
        activitySampleTimer = sampleTimer
    }

    static func nextBoundary(
        after date: Date,
        intervalMinutes: Int,
        calendar: Calendar
    ) -> Date? {
        guard intervalMinutes > 0 else {
            return nil
        }

        let dayStart = calendar.startOfDay(for: date)
        guard let elapsedMinutes = calendar.dateComponents(
            [.minute],
            from: dayStart,
            to: date
        ).minute else {
            return nil
        }

        guard let minuteStart = calendar.dateInterval(of: .minute, for: date)?.start else {
            return nil
        }

        let minutesUntilBoundary = intervalMinutes
            - (elapsedMinutes % intervalMinutes)
        return calendar.date(
            byAdding: .minute,
            value: minutesUntilBoundary,
            to: minuteStart
        )
    }

    @objc private func timerFired(_ firedTimer: Timer) {
        guard firedTimer === timer else {
            return
        }

        guard !isPaused else {
            return
        }

        invalidateScheduledTimers()
        regularFireDate = nil
        nextFireDate = nil

        deliverScheduledBreak(checkForEntireCycleIdle: true)
    }

    @objc private func adaptiveBreakTimerFired(_ firedTimer: Timer) {
        guard firedTimer === adaptiveBreakTimer, !isPaused else {
            return
        }

        sampleActivity()
        guard !observedIdleGap else {
            return
        }

        let nextCycleStart = regularFireDate ?? Date()
        invalidateScheduledTimers()
        regularFireDate = nil
        nextFireDate = nil

        deliverScheduledBreak(
            checkForEntireCycleIdle: false,
            scheduleAfter: nextCycleStart
        )
    }

    @objc private func snoozeEndTimerFired(_ firedTimer: Timer) {
        guard firedTimer === snoozeEndTimer, !isPaused else {
            return
        }

        invalidateScheduledTimers()
        snoozeUntil = nil
        userDefaults.removeObject(forKey: Self.snoozeUntilDefaultsKey)
        nextFireDate = nil
        onSnoozeEnded()

        deliverScheduledBreak(checkForEntireCycleIdle: false)
    }

    private func deliverScheduledBreak(
        checkForEntireCycleIdle: Bool,
        scheduleAfter date: Date = Date()
    ) {
        if suppressionIsActive() {
            onBreakSkipped()
        } else {
            let idleThreshold = TimeInterval(intervalMinutes * 60)
            let wasIdleForEntireCycle = checkForEntireCycleIdle
                && PresentationGuard.secondsSinceLastInput() > idleThreshold

            if !wasIdleForEntireCycle {
                onBreak()
            }
        }

        scheduleNextBoundary(after: date)
    }

    @objc private func preWarningTimerFired(_ firedTimer: Timer) {
        guard firedTimer === preWarningTimer else {
            return
        }

        preWarningTimer = nil

        guard !isPaused, !suppressionIsActive() else {
            return
        }

        onPreWarning()
    }

    @objc private func adaptivePreWarningTimerFired(_ firedTimer: Timer) {
        guard firedTimer === adaptivePreWarningTimer else {
            return
        }

        adaptivePreWarningTimer = nil
        sampleActivity()

        guard
            !isPaused,
            !observedIdleGap,
            !suppressionIsActive()
        else {
            return
        }

        onPreWarning()
    }

    private func suppressionIsActive() -> Bool {
        PresentationGuard.shouldSuppressBreak() || shouldSuppressBreak()
    }

    @objc private func activitySampleTimerFired(_ firedTimer: Timer) {
        guard firedTimer === activitySampleTimer else {
            return
        }

        sampleActivity()
    }

    private func sampleActivity() {
        guard
            !observedIdleGap,
            let activityTrackingStartDate,
            let previousInputDate = lastObservedInputDate
        else {
            return
        }

        let now = Date()
        let elapsedCycleTime = max(
            0,
            now.timeIntervalSince(activityTrackingStartDate)
        )
        let sampledIdleTime = max(0, PresentationGuard.secondsSinceLastInput())
        let idleTimeWithinCycle = min(sampledIdleTime, elapsedCycleTime)
        let latestInputDate = now.addingTimeInterval(-idleTimeWithinCycle)

        if latestInputDate.timeIntervalSince(previousInputDate)
            > Self.idleGapThreshold {
            markObservedIdleGap()
            return
        }

        let updatedInputDate = max(previousInputDate, latestInputDate)
        lastObservedInputDate = updatedInputDate

        guard now.timeIntervalSince(updatedInputDate) > Self.idleGapThreshold else {
            return
        }

        markObservedIdleGap()
    }

    private func markObservedIdleGap() {
        observedIdleGap = true
        adaptivePreWarningTimer?.invalidate()
        adaptivePreWarningTimer = nil
        adaptiveBreakTimer?.invalidate()
        adaptiveBreakTimer = nil
        activitySampleTimer?.invalidate()
        activitySampleTimer = nil
        nextFireDate = regularFireDate
    }

    private func invalidateScheduledTimers() {
        preWarningTimer?.invalidate()
        preWarningTimer = nil
        timer?.invalidate()
        timer = nil
        adaptivePreWarningTimer?.invalidate()
        adaptivePreWarningTimer = nil
        adaptiveBreakTimer?.invalidate()
        adaptiveBreakTimer = nil
        activitySampleTimer?.invalidate()
        activitySampleTimer = nil
        snoozeEndTimer?.invalidate()
        snoozeEndTimer = nil
        activityTrackingStartDate = nil
        lastObservedInputDate = nil
    }

    @objc private func workspaceDidWake(_ notification: Notification) {
        scheduleNextBoundary()
    }
}
