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

final class HUDPanelController: NSObject {
    static let breakCountDefaultsKey = "breakCount"

    private let panelSize = HUDLayout.panelSize
    private let countdownInterval: TimeInterval = 1.0 / 30.0
    private let userDefaults: UserDefaults
    private let onBreakCompleted: () -> Void
    private let onBreakSkipped: () -> Void
    private let onSnoozeRequested: () -> Void
    private let onMiniBreakStarted: () -> Void
    private let onMiniBreakEnded: () -> Void
    private let displayDimmingController = DisplayDimmingController()

    private var theme: Theme
    private var soundEnabled: Bool
    private var eyeExerciseEnabled: Bool
    private var escapeShortcutEnabled: Bool
    private var dimScreenEnabled: Bool
    private var activeBreakDisplayID: CGDirectDisplayID?
    private var panel: NonActivatingHUDPanel?
    private var viewState: HUDViewState?
    private var countdownTimer: Timer?
    private var countdownEndDate: Date?
    private var countdownPausedAt: Date?
    private var dismissalWorkItem: DispatchWorkItem?
    private var escapeKeyEventTap: CFMachPort?
    private var escapeKeyEventTapSource: CFRunLoopSource?
    private var escapeKeyEventTapRunLoop: CFRunLoop?

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
            controller.viewState?.isMiniMode != true
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
        eyeExerciseEnabled: Bool,
        escapeShortcutEnabled: Bool,
        dimScreenEnabled: Bool,
        userDefaults: UserDefaults = .standard,
        onBreakCompleted: @escaping () -> Void = {},
        onBreakSkipped: @escaping () -> Void = {},
        onSnoozeRequested: @escaping () -> Void = {},
        onMiniBreakStarted: @escaping () -> Void = {},
        onMiniBreakEnded: @escaping () -> Void = {}
    ) {
        self.theme = theme
        self.soundEnabled = soundEnabled
        self.eyeExerciseEnabled = eyeExerciseEnabled
        self.escapeShortcutEnabled = escapeShortcutEnabled
        self.dimScreenEnabled = dimScreenEnabled
        self.userDefaults = userDefaults
        self.onBreakCompleted = onBreakCompleted
        self.onBreakSkipped = onBreakSkipped
        self.onSnoozeRequested = onSnoozeRequested
        self.onMiniBreakStarted = onMiniBreakStarted
        self.onMiniBreakEnded = onMiniBreakEnded
        super.init()
    }

    deinit {
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

    func setEyeExerciseEnabled(_ eyeExerciseEnabled: Bool) {
        self.eyeExerciseEnabled = eyeExerciseEnabled
        viewState?.eyeExerciseEnabled = eyeExerciseEnabled
    }

    func setEscapeShortcutEnabled(_ escapeShortcutEnabled: Bool) {
        self.escapeShortcutEnabled = escapeShortcutEnabled

        if escapeShortcutEnabled {
            if panel != nil, viewState?.isDismissing == false {
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

    func setPaused(_ shouldPause: Bool) {
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
            state.remainingSeconds = max(0, endDate.timeIntervalSince(now))
            state.isPaused = true
            countdownPausedAt = now
            countdownTimer?.invalidate()
            countdownTimer = nil
            return
        }

        if let pausedAt = countdownPausedAt {
            countdownEndDate = endDate.addingTimeInterval(
                max(0, now.timeIntervalSince(pausedAt))
            )
        }

        countdownPausedAt = nil
        state.isPaused = false
        startCountdownTimer()
    }

    @discardableResult
    func show(
        miniMode: Bool,
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
            eyeExerciseEnabled: eyeExerciseEnabled,
            completedBreakCount: completedBreakCount,
            currentStreak: currentStreak,
            isNightMode: isNightMode,
            isMiniMode: miniMode,
            screenHasNotch: screenHasNotch,
            date: now,
            calendar: calendar,
            frontmostApplicationBundleIdentifier: frontmostApplicationBundleIdentifier
        )

        if miniMode {
            viewState = state
            activeBreakDisplayID = breakDisplayID
            countdownEndDate = now.addingTimeInterval(state.duration)
            startCountdownTimer()
            dimActiveBreakIfEnabled()
            onMiniBreakStarted()
            playSound(named: "Morse", volume: 0.06)
            return true
        }

        let rootView = HUDView(
            state: state,
            onDismiss: { [weak self] in
                self?.requestDismissal(
                    playsSound: true,
                    completedBreak: false
                )
            },
            onHoverChanged: { [weak self] isHovering in
                self?.setPaused(isHovering)
            }
        )
        let hostingView = FirstMouseHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.handlesRightClickAt = { [weak state] location in
            guard
                let state,
                !state.isDismissing,
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
        activeBreakDisplayID = breakDisplayID
        countdownEndDate = Date().addingTimeInterval(state.duration)
        startCountdownTimer()
        dimActiveBreakIfEnabled()

        newPanel.orderFrontRegardless()
        playSound(named: "Morse", volume: 0.06)

        if escapeShortcutEnabled {
            installEscapeKeyMonitors()
        }

        return true
    }

    func closeImmediately(restoringBrightnessImmediately: Bool = false) {
        let wasMiniModeBreak = viewState?.isMiniMode == true

        displayDimmingController.restore(
            immediately: restoringBrightnessImmediately
        )
        activeBreakDisplayID = nil
        removeEscapeKeyEventTap()

        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownEndDate = nil
        countdownPausedAt = nil

        dismissalWorkItem?.cancel()
        dismissalWorkItem = nil

        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        viewState = nil

        if wasMiniModeBreak {
            onMiniBreakEnded()
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
    func dismissImmediatelyAsSkipped() -> Bool {
        guard let state = viewState, !state.isDismissing else {
            return false
        }

        onBreakSkipped()
        closeImmediately()
        return true
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
            let endDate = countdownEndDate,
            let state = viewState,
            !state.isDismissing
        else {
            return
        }

        let remaining = max(0, endDate.timeIntervalSinceNow)
        state.remainingSeconds = remaining

        if remaining <= 0 {
            requestDismissal(
                playsSound: false,
                completedBreak: true
            )
        }
    }

    @discardableResult
    private func requestDismissal(
        playsSound: Bool,
        completedBreak: Bool
    ) -> Bool {
        guard let state = viewState, !state.isDismissing else {
            return false
        }

        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownEndDate = nil
        countdownPausedAt = nil

        state.isDismissing = true
        state.isPaused = false

        if completedBreak {
            let completedBreakCount = max(
                0,
                userDefaults.integer(forKey: Self.breakCountDefaultsKey)
            )
            userDefaults.set(
                completedBreakCount + 1,
                forKey: Self.breakCountDefaultsKey
            )
            onBreakCompleted()
            playSound(named: "Blow", volume: 0.05)
        } else {
            onBreakSkipped()

            if playsSound {
                playSound(named: "Pop", volume: 0.06)
            }
        }

        if state.isMiniMode {
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
