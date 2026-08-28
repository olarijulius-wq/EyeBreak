import AppKit
import CoreGraphics
import SwiftUI

private final class NonActivatingHUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    var onRightClick: (() -> Void)?
    var handlesRightClickAt: ((NSPoint) -> Bool)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func rightMouseDown(with event: NSEvent) {
        var location = convert(event.locationInWindow, from: nil)

        if !isFlipped {
            location.y = bounds.height - location.y
        }

        if handlesRightClickAt?(location) == true {
            onRightClick?()
        } else {
            super.rightMouseDown(with: event)
        }
    }
}

struct BreakTiming: Equatable {
    let heldSeconds: TimeInterval
    let countdownSeconds: TimeInterval
}

final class HUDPanelController: NSObject {
    static let breakCountDefaultsKey = "breakCount"

    private let panelSize = HUDLayout.panelSize
    private let countdownInterval: TimeInterval = 1.0 / 30.0
    private let recentInputThreshold: TimeInterval = 2.0
    private let userDefaults: UserDefaults
    private let onBreakCompleted: (BreakTiming) -> Void
    private let onBreakSkipped: (BreakTiming) -> Void
    private let onSnoozeRequested: () -> Void
    private let onSilentBreakStarted: () -> Void
    private let onSilentBreakEnded: () -> Void
    private let displayDimmingController = DisplayDimmingController()

    private var theme: Theme
    private var soundEnabled: Bool
    private var focusExerciseEnabled: Bool
    private var escapeShortcutEnabled: Bool
    private var dimScreenEnabled: Bool
    private var requireStillnessEnabled: Bool
    private var cameraAttentionEnabled: Bool
    private var activeBreakDisplayID: CGDirectDisplayID?
    private var panel: NonActivatingHUDPanel?
    private var viewState: HUDViewState?
    private var countdownTimer: Timer?
    private var countdownEndDate: Date?
    private var countdownPausedAt: Date?
    private var lastCountdownTickDate: Date?
    private var heldSeconds: TimeInterval = 0
    private var countdownSeconds: TimeInterval = 0
    private var didReportBreakTiming = false
    private var dismissalWorkItem: DispatchWorkItem?
    private var informationalExpirationHandler: (() -> Void)?
    private var escapeKeyEventTap: CFMachPort?
    private var escapeKeyEventTapSource: CFRunLoopSource?
    private var escapeKeyEventTapRunLoop: CFRunLoop?
    private var cameraAttentionDetector: CameraAttentionDetector?
    private var cameraAttentionGeneration = 0
    private var isFacingScreen = false

    private static let escapeKeyEventTapCallback: CGEventTapCallBack = {
        _, eventType, event, userInfo in
        guard
            eventType == .keyDown,
            event.getIntegerValueField(.keyboardEventKeycode) == 53,
            let userInfo
        else {
            return Unmanaged.passUnretained(event)
        }

        let controller = Unmanaged<HUDPanelController>
            .fromOpaque(userInfo)
            .takeUnretainedValue()
        guard
            controller.escapeShortcutEnabled,
            controller.viewState?.isSilentMode != true,
            controller.viewState?.isInformational != true
        else {
            return Unmanaged.passUnretained(event)
        }

        controller.requestDismissal(
            playsSound: true,
            completedBreak: false
        )

        return Unmanaged.passUnretained(event)
    }

    init(
        theme: Theme,
        soundEnabled: Bool,
        focusExerciseEnabled: Bool,
        escapeShortcutEnabled: Bool,
        dimScreenEnabled: Bool,
        requireStillnessEnabled: Bool = false,
        cameraAttentionEnabled: Bool = false,
        userDefaults: UserDefaults = .standard,
        onBreakCompleted: @escaping (BreakTiming) -> Void = { _ in },
        onBreakSkipped: @escaping (BreakTiming) -> Void = { _ in },
        onSnoozeRequested: @escaping () -> Void = {},
        onSilentBreakStarted: @escaping () -> Void = {},
        onSilentBreakEnded: @escaping () -> Void = {}
    ) {
        self.theme = theme
        self.soundEnabled = soundEnabled
        self.focusExerciseEnabled = focusExerciseEnabled
        self.escapeShortcutEnabled = escapeShortcutEnabled
        self.dimScreenEnabled = dimScreenEnabled
        self.requireStillnessEnabled = requireStillnessEnabled
        self.cameraAttentionEnabled = cameraAttentionEnabled
        self.userDefaults = userDefaults
        self.onBreakCompleted = onBreakCompleted
        self.onBreakSkipped = onBreakSkipped
        self.onSnoozeRequested = onSnoozeRequested
        self.onSilentBreakStarted = onSilentBreakStarted
        self.onSilentBreakEnded = onSilentBreakEnded
        super.init()
    }

    deinit {
        stopCameraAttention()
        removeEscapeKeyEventTap()
    }

    func setTheme(_ theme: Theme) {
        self.theme = theme

        if viewState?.isNightMode != true {
            viewState?.theme = theme
        }
    }

    func setSoundEnabled(_ soundEnabled: Bool) {
        self.soundEnabled = soundEnabled
    }

    func setFocusExerciseEnabled(_ focusExerciseEnabled: Bool) {
        self.focusExerciseEnabled = focusExerciseEnabled
        viewState?.focusExerciseEnabled = focusExerciseEnabled
    }

    func setEscapeShortcutEnabled(_ escapeShortcutEnabled: Bool) {
        self.escapeShortcutEnabled = escapeShortcutEnabled

        if escapeShortcutEnabled {
            if
                panel != nil,
                viewState?.isDismissing == false,
                viewState?.isInformational != true
            {
                installEscapeKeyMonitors()
            }
        } else {
            removeEscapeKeyEventTap()
        }
    }

    func setDimScreenEnabled(_ dimScreenEnabled: Bool) {
        self.dimScreenEnabled = dimScreenEnabled

        if dimScreenEnabled, let activeBreakDisplayID, viewState != nil {
            displayDimmingController.dim(displayID: activeBreakDisplayID)
        } else if !dimScreenEnabled {
            displayDimmingController.restore()
        }
    }

    func setRequireStillnessEnabled(_ requireStillnessEnabled: Bool) {
        guard self.requireStillnessEnabled != requireStillnessEnabled else {
            return
        }

        if
            !self.requireStillnessEnabled,
            requireStillnessEnabled,
            viewState?.isPaused == true
        {
            setPaused(false)
        }

        if let state = viewState, !state.isDismissing, !state.isPaused {
            settleActiveTiming(for: state, at: Date())
        }

        self.requireStillnessEnabled = requireStillnessEnabled

        if let state = viewState, !state.isDismissing, !state.isPaused {
            state.isHeld = shouldHoldCountdown(for: state)
        }
    }

    func setCameraAttentionEnabled(_ cameraAttentionEnabled: Bool) {
        if
            self.cameraAttentionEnabled != cameraAttentionEnabled,
            let state = viewState,
            !state.isDismissing,
            !state.isPaused
        {
            settleActiveTiming(for: state, at: Date())
        }

        self.cameraAttentionEnabled = cameraAttentionEnabled

        if cameraAttentionEnabled {
            startCameraAttentionIfNeeded()
        } else {
            stopCameraAttention()
        }

        if let state = viewState, !state.isDismissing, !state.isPaused {
            state.isHeld = shouldHoldCountdown(for: state)
        }
    }

    func setPaused(_ shouldPause: Bool) {
        guard !requireStillnessEnabled else {
            return
        }

        guard
            let state = viewState,
            !state.isDismissing,
            state.isPaused != shouldPause,
            let endDate = countdownEndDate
        else {
            return
        }

        let now = Date()

        if shouldPause {
            var updatedEndDate = endDate
            accountForElapsedTime(
                until: now,
                endDate: &updatedEndDate,
                wasHeld: state.isHeld
            )
            countdownEndDate = updatedEndDate
            state.remainingSeconds = max(
                0,
                updatedEndDate.timeIntervalSince(now)
            )
            state.isHeld = false
            state.isPaused = true
            countdownPausedAt = now
            lastCountdownTickDate = nil
            countdownTimer?.invalidate()
            countdownTimer = nil

            if heldSeconds > state.duration * 3 {
                requestDismissal(
                    playsSound: false,
                    completedBreak: false
                )
            }
            return
        }

        if let pausedAt = countdownPausedAt {
            countdownEndDate = endDate.addingTimeInterval(
                max(0, now.timeIntervalSince(pausedAt))
            )
        }

        countdownPausedAt = nil
        state.isPaused = false
        state.isHeld = false
        lastCountdownTickDate = now
        startCountdownTimer()
    }

    @discardableResult
    func show(
        silentMode: Bool,
        nightModeEnabled: Bool,
        currentStreak: Int,
        at date: Date = Date()
    ) -> Bool {
        if let viewState, !viewState.isDismissing {
            return false
        }

        closeImmediately()

        let now = date
        let targetScreen = Self.screenContainingMouse()
        let screenHasNotch = (targetScreen?.safeAreaInsets.top ?? 0) > 0
        let breakDisplayID = targetScreen.flatMap(Self.displayID)
        let calendar = Calendar.autoupdatingCurrent
        let hour = calendar.component(.hour, from: now)
        let isNightMode = nightModeEnabled && (hour >= 23 || hour < 6)
        let frontmostApplicationBundleIdentifier = NSWorkspace.shared
            .frontmostApplication?
            .bundleIdentifier
        let completedBreakCount = max(
            0,
            userDefaults.integer(forKey: Self.breakCountDefaultsKey)
        )
        let isLongBreak = (completedBreakCount + 1).isMultiple(of: 4)
        let duration = isLongBreak
            ? HUDViewState.longBreakDuration
            : HUDViewState.regularDuration
        let state = HUDViewState(
            theme: isNightMode ? .mono : theme,
            duration: duration,
            focusExerciseEnabled: focusExerciseEnabled,
            completedBreakCount: completedBreakCount,
            currentStreak: currentStreak,
            isNightMode: isNightMode,
            isSilentMode: silentMode,
            screenHasNotch: screenHasNotch,
            date: now,
            calendar: calendar,
            frontmostApplicationBundleIdentifier: frontmostApplicationBundleIdentifier
        )

        if silentMode {
            viewState = state
            activeBreakDisplayID = breakDisplayID
            beginCountdown(for: state, startingAt: Date())
            dimActiveBreakIfEnabled()
            onSilentBreakStarted()
            playSound(named: "Morse", volume: 0.06)
            return true
        }

        return presentVisibleHUD(
            state,
            on: targetScreen,
            breakDisplayID: breakDisplayID
        )
    }

    @discardableResult
    func showFirstRunNotice(
        title: String,
        subtitle: String,
        duration: TimeInterval = 6,
        at date: Date = Date(),
        onExpiration: @escaping () -> Void = {}
    ) -> Bool {
        if let viewState, !viewState.isDismissing {
            return false
        }

        closeImmediately()

        let targetScreen = Self.screenContainingMouse()
        let screenHasNotch = (targetScreen?.safeAreaInsets.top ?? 0) > 0
        let state = HUDViewState(
            theme: theme,
            duration: max(0.1, duration),
            focusExerciseEnabled: false,
            completedBreakCount: max(
                0,
                userDefaults.integer(forKey: Self.breakCountDefaultsKey)
            ),
            currentStreak: 0,
            isNightMode: false,
            isSilentMode: false,
            screenHasNotch: screenHasNotch,
            date: date,
            calendar: .autoupdatingCurrent,
            frontmostApplicationBundleIdentifier: nil,
            messageOverride: (title: title, subtitle: subtitle),
            isInformational: true
        )

        informationalExpirationHandler = onExpiration
        let didPresent = presentVisibleHUD(
            state,
            on: targetScreen,
            breakDisplayID: nil
        )

        if !didPresent {
            informationalExpirationHandler = nil
        }

        return didPresent
    }

    private func presentVisibleHUD(
        _ state: HUDViewState,
        on targetScreen: NSScreen?,
        breakDisplayID: CGDirectDisplayID?
    ) -> Bool {
        let rootView = HUDView(
            state: state,
            onDismiss: { [weak self] in
                guard !state.isInformational else {
                    return
                }

                self?.requestDismissal(
                    playsSound: true,
                    completedBreak: false
                )
            },
            onHoverChanged: { [weak self] isHovering in
                guard !state.isInformational else {
                    return
                }

                self?.setPaused(isHovering)
            }
        )
        let hostingView = FirstMouseHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.handlesRightClickAt = { [weak state] location in
            guard
                let state,
                !state.isDismissing,
                !state.isInformational,
                state.hasCompletedEntrance
            else {
                return false
            }

            let cardSize = state.cardSize
            let restingCardFrame = NSRect(
                x: (HUDLayout.panelSize.width - cardSize.width) / 2,
                y: state.restingCardTopInset,
                width: cardSize.width,
                height: cardSize.height
            )
            let scale = state.remainingSeconds <= 3 ? 0.97 : 1
            let scaledFrame = restingCardFrame.insetBy(
                dx: restingCardFrame.width * (1 - scale) / 2,
                dy: restingCardFrame.height * (1 - scale) / 2
            )
            let localPoint = CGPoint(
                x: (location.x - scaledFrame.minX) / scale,
                y: (location.y - scaledFrame.minY) / scale
            )
            let localBounds = CGRect(origin: .zero, size: cardSize)

            return state.cardShape.shape
                .path(in: localBounds)
                .contains(localPoint)
        }
        hostingView.onRightClick = { [weak self] in
            guard !state.isInformational else {
                return
            }

            guard self?.dismissAsSkipped() == true else {
                return
            }

            self?.onSnoozeRequested()
        }

        let newPanel = NonActivatingHUDPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .statusBar
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.alphaValue = 1
        newPanel.hasShadow = false
        newPanel.becomesKeyOnlyIfNeeded = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.hidesOnDeactivate = false
        newPanel.isReleasedWhenClosed = false
        newPanel.animationBehavior = .none
        newPanel.ignoresMouseEvents = false
        newPanel.contentView = hostingView

        position(newPanel, on: targetScreen)

        panel = newPanel
        viewState = state
        activeBreakDisplayID = state.isInformational
            ? nil
            : breakDisplayID
        beginCountdown(for: state, startingAt: Date())

        if !state.isInformational {
            dimActiveBreakIfEnabled()
        }

        newPanel.orderFrontRegardless()

        if !state.isInformational {
            startCameraAttentionIfNeeded()
            playSound(named: "Morse", volume: 0.06)

            if escapeShortcutEnabled {
                installEscapeKeyMonitors()
            }
        }

        return true
    }

    func closeImmediately(restoringBrightnessImmediately: Bool = false) {
        let wasSilentBreak = viewState?.isSilentMode == true

        stopCameraAttention()
        displayDimmingController.restore(
            immediately: restoringBrightnessImmediately
        )
        activeBreakDisplayID = nil
        removeEscapeKeyEventTap()

        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownEndDate = nil
        countdownPausedAt = nil
        resetBreakTiming()

        dismissalWorkItem?.cancel()
        dismissalWorkItem = nil
        informationalExpirationHandler = nil

        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        viewState = nil

        if wasSilentBreak {
            onSilentBreakEnded()
        }
    }

    @discardableResult
    func dismissAsSkipped(playsSound: Bool = false) -> Bool {
        requestDismissal(
            playsSound: playsSound,
            completedBreak: false
        )
    }

    @discardableResult
    func dismissActiveSilentBreakAsSkipped() -> Bool {
        guard viewState?.isSilentMode == true else {
            return false
        }

        return requestDismissal(
            playsSound: false,
            completedBreak: false
        )
    }

    @discardableResult
    func dismissImmediatelyAsSkipped() -> Bool {
        guard viewState?.isDismissing == false else {
            return false
        }

        let didDismiss = requestDismissal(
            playsSound: false,
            completedBreak: false
        )

        if didDismiss {
            closeImmediately()
        }

        return didDismiss
    }

    private func position(_ panel: NSPanel, on targetScreen: NSScreen?) {
        guard let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let frame = NSRect(
            x: screen.frame.midX - (panelSize.width / 2),
            y: screen.frame.maxY - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )

        panel.setFrame(frame, display: false, animate: false)
    }

    private func dimActiveBreakIfEnabled() {
        guard dimScreenEnabled, let activeBreakDisplayID else {
            return
        }

        displayDimmingController.dim(displayID: activeBreakDisplayID)
    }

    private static func screenContainingMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }

    private func installEscapeKeyMonitors() {
        guard escapeShortcutEnabled, escapeKeyEventTap == nil else {
            return
        }

        let keyDownMask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: keyDownMask,
            callback: Self.escapeKeyEventTapCallback,
            userInfo: userInfo
        ) else {
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            eventTap,
            0
        ) else {
            CFMachPortInvalidate(eventTap)
            return
        }

        let runLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        escapeKeyEventTap = eventTap
        escapeKeyEventTapSource = source
        escapeKeyEventTapRunLoop = runLoop
    }

    private func removeEscapeKeyEventTap() {
        if let eventTap = escapeKeyEventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let source = escapeKeyEventTapSource {
            let runLoop = escapeKeyEventTapRunLoop ?? CFRunLoopGetCurrent()
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }

        if let eventTap = escapeKeyEventTap {
            CFMachPortInvalidate(eventTap)
        }

        escapeKeyEventTapSource = nil
        escapeKeyEventTap = nil
        escapeKeyEventTapRunLoop = nil
    }

    private func beginCountdown(
        for state: HUDViewState,
        startingAt startDate: Date
    ) {
        resetBreakTiming()
        countdownEndDate = startDate.addingTimeInterval(state.duration)
        countdownPausedAt = nil
        lastCountdownTickDate = startDate
        state.isHeld = false
        startCountdownTimer()
    }

    private func resetBreakTiming() {
        lastCountdownTickDate = nil
        heldSeconds = 0
        countdownSeconds = 0
        didReportBreakTiming = false
    }

    private func accountForElapsedTime(
        until now: Date,
        endDate: inout Date,
        wasHeld: Bool
    ) {
        guard let previousTickDate = lastCountdownTickDate else {
            lastCountdownTickDate = now
            return
        }

        let elapsed = max(0, now.timeIntervalSince(previousTickDate))

        if wasHeld {
            endDate = endDate.addingTimeInterval(elapsed)
            heldSeconds += elapsed
        } else {
            let remainingAtPreviousTick = max(
                0,
                endDate.timeIntervalSince(previousTickDate)
            )
            countdownSeconds += min(elapsed, remainingAtPreviousTick)
        }

        lastCountdownTickDate = now
    }

    private func settleActiveTiming(for state: HUDViewState, at now: Date) {
        guard !state.isPaused, var endDate = countdownEndDate else {
            return
        }

        accountForElapsedTime(
            until: now,
            endDate: &endDate,
            wasHeld: state.isHeld
        )
        countdownEndDate = endDate
        state.remainingSeconds = max(0, endDate.timeIntervalSince(now))
    }

    private func startCountdownTimer() {
        countdownTimer?.invalidate()

        let timer = Timer(
            timeInterval: countdownInterval,
            target: self,
            selector: #selector(updateCountdown(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    @objc private func updateCountdown(_ firedTimer: Timer) {
        guard firedTimer === countdownTimer else {
            return
        }

        guard
            var endDate = countdownEndDate,
            let state = viewState,
            !state.isDismissing
        else {
            return
        }

        let now = Date()
        let shouldHold = shouldHoldCountdown(for: state)
        accountForElapsedTime(
            until: now,
            endDate: &endDate,
            wasHeld: shouldHold
        )
        countdownEndDate = endDate
        state.isHeld = shouldHold

        let remaining = max(0, endDate.timeIntervalSince(now))
        state.remainingSeconds = remaining

        if heldSeconds > state.duration * 3 {
            requestDismissal(
                playsSound: false,
                completedBreak: false
            )
            return
        }

        if remaining <= 0 {
            requestDismissal(
                playsSound: false,
                completedBreak: true
            )
        }
    }

    private func shouldHoldCountdown(for state: HUDViewState) -> Bool {
        guard !state.isInformational, !state.isSilentMode else {
            return false
        }

        let shouldHoldForStillness = requireStillnessEnabled
            && PresentationGuard.secondsSinceLastInput() < recentInputThreshold
        let shouldHoldForCamera = cameraAttentionEnabled && isFacingScreen
        return shouldHoldForStillness || shouldHoldForCamera
    }

    private func startCameraAttentionIfNeeded() {
        guard
            cameraAttentionEnabled,
            panel != nil,
            let state = viewState,
            !state.isDismissing,
            !state.isInformational,
            !state.isSilentMode
        else {
            return
        }

        if let cameraAttentionDetector {
            cameraAttentionDetector.start()
            return
        }

        cameraAttentionGeneration += 1
        let generation = cameraAttentionGeneration
        let detector = CameraAttentionDetector { [weak self] isFacingScreen in
            guard
                let self,
                self.cameraAttentionGeneration == generation
            else {
                return
            }

            self.updateCameraAttention(isFacingScreen)
        }
        cameraAttentionDetector = detector
        detector.start()
    }

    private func stopCameraAttention() {
        cameraAttentionGeneration += 1
        cameraAttentionDetector?.stop()
        cameraAttentionDetector = nil
        isFacingScreen = false
    }

    private func updateCameraAttention(_ isFacingScreen: Bool) {
        guard self.isFacingScreen != isFacingScreen else {
            return
        }

        if let state = viewState, !state.isDismissing, !state.isPaused {
            settleActiveTiming(for: state, at: Date())
        }

        self.isFacingScreen = isFacingScreen

        if let state = viewState, !state.isDismissing, !state.isPaused {
            state.isHeld = shouldHoldCountdown(for: state)
        }
    }

    @discardableResult
    private func requestDismissal(
        playsSound: Bool,
        completedBreak: Bool
    ) -> Bool {
        guard
            let state = viewState,
            !state.isDismissing,
            !didReportBreakTiming
        else {
            return false
        }

        settleActiveTiming(for: state, at: Date())
        let timing = BreakTiming(
            heldSeconds: heldSeconds,
            countdownSeconds: countdownSeconds
        )
        didReportBreakTiming = true

        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownEndDate = nil
        countdownPausedAt = nil
        lastCountdownTickDate = nil
        heldSeconds = 0
        countdownSeconds = 0

        state.isDismissing = true
        state.isPaused = false
        state.isHeld = false

        let informationalExpiration = state.isInformational
            && completedBreak
            ? informationalExpirationHandler
            : nil

        if state.isInformational {
            informationalExpirationHandler = nil
        }

        if state.isInformational {
            // Informational HUDs use the countdown animation but do not
            // participate in break cadence, history, or sounds.
        } else if completedBreak {
            let completedBreakCount = max(
                0,
                userDefaults.integer(forKey: Self.breakCountDefaultsKey)
            )
            userDefaults.set(
                completedBreakCount + 1,
                forKey: Self.breakCountDefaultsKey
            )
            onBreakCompleted(timing)
            playSound(named: "Blow", volume: 0.05)
        } else {
            onBreakSkipped(timing)

            if playsSound {
                playSound(named: "Pop", volume: 0.06)
            }
        }

        informationalExpiration?()

        if state.isSilentMode {
            closeImmediately()
            return true
        }

        let visiblePanel = panel
        let workItem = DispatchWorkItem { [weak self, weak visiblePanel] in
            guard let self, self.panel === visiblePanel else {
                return
            }

            self.closeImmediately()
        }
        dismissalWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + state.exitStyle.duration + 0.03,
            execute: workItem
        )
        return true
    }

    private func playSound(named name: String, volume: Float) {
        guard
            soundEnabled,
            let sound = NSSound(named: NSSound.Name(name))
        else {
            return
        }

        sound.volume = viewState?.isNightMode == true ? 0 : volume
        sound.play()
    }
}
