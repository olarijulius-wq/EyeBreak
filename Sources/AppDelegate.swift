import AppKit
import ServiceManagement

private enum ThemeSelection {
    static let autoRawValue = "auto"

    static func normalizedRawValue(_ storedValue: String?) -> String {
        guard let storedValue else {
            return Theme.graphite.rawValue
        }

        if storedValue == autoRawValue || Theme(rawValue: storedValue) != nil {
            return storedValue
        }

        return Theme.graphite.rawValue
    }

    static func resolve(
        rawValue: String,
        date: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> Theme {
        guard rawValue == autoRawValue else {
            return Theme(rawValue: rawValue) ?? .graphite
        }

        let hour = calendar.component(.hour, from: date)
        return Theme.automatic(forHour: hour)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let selectedThemeDefaultsKey = "selectedTheme"
    private static let soundEnabledDefaultsKey = "soundEnabled"
    private static let eyeExerciseEnabledDefaultsKey = "eyeExerciseEnabled"
    private static let escapeShortcutEnabledDefaultsKey = "escapeShortcutEnabled"
    private static let miniModeEnabledDefaultsKey = "miniModeEnabled"
    private static let nightModeEnabledDefaultsKey = "nightModeEnabled"
    private static let dimScreenEnabledDefaultsKey = "dimScreenEnabled"
    private static let calendarAwareEnabledDefaultsKey = "calendarAwareEnabled"
    private static let snoozeDuration: TimeInterval = 30 * 60

    private static let snoozeTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var selectedThemeRawValue = ThemeSelection.normalizedRawValue(
        UserDefaults.standard.string(
            forKey: AppDelegate.selectedThemeDefaultsKey
        )
    )
    private var soundEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.soundEnabledDefaultsKey
    ) as? Bool ?? true
    private var eyeExerciseEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.eyeExerciseEnabledDefaultsKey
    ) as? Bool ?? true
    private var escapeShortcutEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.escapeShortcutEnabledDefaultsKey
    ) as? Bool ?? false
    private var miniModeEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.miniModeEnabledDefaultsKey
    ) as? Bool ?? false
    private var nightModeEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.nightModeEnabledDefaultsKey
    ) as? Bool ?? true
    private var dimScreenEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.dimScreenEnabledDefaultsKey
    ) as? Bool ?? false
    private var calendarAwareEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.calendarAwareEnabledDefaultsKey
    ) as? Bool ?? false
    private let breakHistoryStore = BreakHistoryStore()
    private let calendarAwareness = CalendarAwareness()

    private lazy var hudController = HUDPanelController(
        theme: ThemeSelection.resolve(rawValue: selectedThemeRawValue),
        soundEnabled: soundEnabled,
        eyeExerciseEnabled: eyeExerciseEnabled,
        escapeShortcutEnabled: escapeShortcutEnabled,
        dimScreenEnabled: dimScreenEnabled,
        onBreakCompleted: { [weak self] in
            self?.breakHistoryStore.recordCompletedBreak()
        },
        onBreakSkipped: { [weak self] in
            self?.breakHistoryStore.recordSkippedBreak()
        },
        onSnoozeRequested: { [weak self] in
            self?.beginSnooze()
        },
        onMiniBreakStarted: { [weak self] in
            self?.startMiniModeStatusPresentation()
        },
        onMiniBreakEnded: { [weak self] in
            self?.stopMiniModeStatusPresentation()
        }
    )
    private lazy var statsPanelController = StatsPanelController(
        historyStore: breakHistoryStore
    )
    private var statusItem: NSStatusItem?
    private var statusIconTimer: Timer?
    private var statusIconPulseGeneration = 0
    private var isStatusIconPulsing = false
    private var miniModeStatusPulseGeneration = 0
    private var isMiniModeBreakActive = false
    private var pauseMenuItem: NSMenuItem?
    private var adaptiveTimingMenuItem: NSMenuItem?
    private var soundMenuItem: NSMenuItem?
    private var miniModeMenuItem: NSMenuItem?
    private var nightModeMenuItem: NSMenuItem?
    private var dimScreenMenuItem: NSMenuItem?
    private var calendarAwareMenuItem: NSMenuItem?
    private var eyeExerciseMenuItem: NSMenuItem?
    private var escapeShortcutMenuItem: NSMenuItem?
    private var escapeShortcutEnabledMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?
    private var intervalMenuItems: [NSMenuItem] = []
    private var themeMenuItems: [NSMenuItem] = []

    private lazy var scheduler = BreakScheduler(
        onPreWarning: { [weak self] in
            self?.showPreWarning()
        },
        onBreak: { [weak self] in
            self?.showHUD()
        },
        shouldSuppressBreak: { [weak self] in
            guard let self, self.calendarAwareEnabled else {
                return false
            }

            return self.calendarAwareness.isMeetingInProgress()
        },
        onBreakSkipped: { [weak self] in
            self?.breakHistoryStore.recordSkippedBreak()
        },
        onSnoozeEnded: { [weak self] in
            self?.refreshSnoozePresentation()
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UserDefaults.standard.register(defaults: [
            BreakScheduler.breakIntervalDefaultsKey: BreakScheduler.defaultIntervalMinutes,
            HUDPanelController.breakCountDefaultsKey: 0,
            Self.soundEnabledDefaultsKey: true,
            Self.eyeExerciseEnabledDefaultsKey: true,
            Self.escapeShortcutEnabledDefaultsKey: false,
            Self.miniModeEnabledDefaultsKey: false,
            Self.nightModeEnabledDefaultsKey: true,
            Self.dimScreenEnabledDefaultsKey: false,
            Self.calendarAwareEnabledDefaultsKey: false,
            BreakScheduler.adaptiveTimingDefaultsKey: false
        ])
        breakHistoryStore.pruneOlderThan30Days()
        configureStatusItem()
        scheduler.start()
        startStatusIconTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusIconTimer?.invalidate()
        statusIconTimer = nil
        scheduler.stop()
        _ = hudController.dismissImmediatelyAsSkipped()
        hudController.closeImmediately(restoringBrightnessImmediately: true)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "eye",
                accessibilityDescription: "EyeBreak"
            )
            button.image?.isTemplate = true
            button.imagePosition = .imageOnly
            button.toolTip = "EyeBreak"
        }

        let menu = NSMenu()
        menu.delegate = self

        let showItem = NSMenuItem(
            title: "Show now",
            action: #selector(showNow),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        let pauseItem = NSMenuItem(
            title: "Pause",
            action: #selector(togglePaused),
            keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)
        pauseMenuItem = pauseItem

        let snoozeItem = NSMenuItem(
            title: "Snooze 30 min",
            action: #selector(snoozeThirtyMinutes),
            keyEquivalent: ""
        )
        snoozeItem.target = self
        menu.addItem(snoozeItem)

        let intervalItem = NSMenuItem(
            title: "Interval",
            action: nil,
            keyEquivalent: ""
        )
        let intervalMenu = NSMenu(title: "Interval")

        for minutes in BreakScheduler.supportedIntervalMinutes {
            let item = NSMenuItem(
                title: "\(minutes) minutes",
                action: #selector(selectInterval(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = minutes
            item.state = minutes == scheduler.intervalMinutes ? .on : .off
            intervalMenu.addItem(item)
            intervalMenuItems.append(item)
        }

        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        let adaptiveItem = NSMenuItem(
            title: "Adaptive timing",
            action: #selector(toggleAdaptiveTiming),
            keyEquivalent: ""
        )
        adaptiveItem.target = self
        adaptiveItem.state = scheduler.adaptiveTimingEnabled ? .on : .off
        menu.addItem(adaptiveItem)
        adaptiveTimingMenuItem = adaptiveItem

        let themeItem = NSMenuItem(
            title: "Theme",
            action: nil,
            keyEquivalent: ""
        )
        let themeMenu = NSMenu(title: "Theme")

        let autoThemeItem = NSMenuItem(
            title: "Auto",
            action: #selector(selectTheme(_:)),
            keyEquivalent: ""
        )
        autoThemeItem.target = self
        autoThemeItem.representedObject = ThemeSelection.autoRawValue
        autoThemeItem.state = selectedThemeRawValue == ThemeSelection.autoRawValue
            ? .on
            : .off
        themeMenu.addItem(autoThemeItem)
        themeMenuItems.append(autoThemeItem)

        for theme in Theme.allCases {
            let item = NSMenuItem(
                title: theme.displayName,
                action: #selector(selectTheme(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = theme.rawValue
            item.state = theme.rawValue == selectedThemeRawValue ? .on : .off
            themeMenu.addItem(item)
            themeMenuItems.append(item)
        }

        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        let soundItem = NSMenuItem(
            title: "Sound",
            action: #selector(toggleSound),
            keyEquivalent: ""
        )
        soundItem.target = self
        soundItem.state = soundEnabled ? .on : .off
        menu.addItem(soundItem)
        soundMenuItem = soundItem

        let miniModeItem = NSMenuItem(
            title: "Mini mode",
            action: #selector(toggleMiniMode),
            keyEquivalent: ""
        )
        miniModeItem.target = self
        miniModeItem.state = miniModeEnabled ? .on : .off
        menu.addItem(miniModeItem)
        miniModeMenuItem = miniModeItem

        let nightModeItem = NSMenuItem(
            title: "Night mode",
            action: #selector(toggleNightMode),
            keyEquivalent: ""
        )
        nightModeItem.target = self
        nightModeItem.state = nightModeEnabled ? .on : .off
        menu.addItem(nightModeItem)
        nightModeMenuItem = nightModeItem

        let dimScreenItem = NSMenuItem(
            title: "Dim screen",
            action: #selector(toggleDimScreen),
            keyEquivalent: ""
        )
        dimScreenItem.target = self
        dimScreenItem.state = dimScreenEnabled ? .on : .off
        menu.addItem(dimScreenItem)
        dimScreenMenuItem = dimScreenItem

        let calendarAwareItem = NSMenuItem(
            title: "Skip during meetings",
            action: #selector(toggleCalendarAwareness),
            keyEquivalent: ""
        )
        calendarAwareItem.target = self
        calendarAwareItem.state = calendarAwareEnabled ? .on : .off
        menu.addItem(calendarAwareItem)
        calendarAwareMenuItem = calendarAwareItem

        let eyeExerciseItem = NSMenuItem(
            title: "Eye exercise",
            action: #selector(toggleEyeExercise),
            keyEquivalent: ""
        )
        eyeExerciseItem.target = self
        eyeExerciseItem.state = eyeExerciseEnabled ? .on : .off
        menu.addItem(eyeExerciseItem)
        eyeExerciseMenuItem = eyeExerciseItem

        let launchItem = NSMenuItem(
            title: "Launch at login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchItem)
        launchAtLoginMenuItem = launchItem

        menu.addItem(.separator())

        let escapeShortcutItem = NSMenuItem(
            title: "Escape shortcut",
            action: nil,
            keyEquivalent: ""
        )
        escapeShortcutItem.state = escapeShortcutEnabled ? .on : .off

        let escapeShortcutMenu = NSMenu(title: "Escape shortcut")
        let escapeShortcutEnabledItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEscapeShortcut),
            keyEquivalent: ""
        )
        escapeShortcutEnabledItem.target = self
        escapeShortcutEnabledItem.state = escapeShortcutEnabled ? .on : .off
        escapeShortcutMenu.addItem(escapeShortcutEnabledItem)

        let enableEscapeItem = NSMenuItem(
            title: "Enable Escape shortcut…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        enableEscapeItem.target = self
        escapeShortcutMenu.addItem(enableEscapeItem)

        escapeShortcutItem.submenu = escapeShortcutMenu
        menu.addItem(escapeShortcutItem)
        escapeShortcutMenuItem = escapeShortcutItem
        escapeShortcutEnabledMenuItem = escapeShortcutEnabledItem

        menu.addItem(.separator())

        let statsItem = NSMenuItem(
            title: "Stats",
            action: #selector(showStats),
            keyEquivalent: ""
        )
        statsItem.target = self
        menu.addItem(statsItem)

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        launchAtLoginMenuItem?.state = SMAppService.mainApp.status == .enabled
            ? .on
            : .off
        refreshSnoozePresentation()
    }

    @objc private func showNow() {
        showHUD()
    }

    @objc private func togglePaused() {
        guard scheduler.activeSnoozeUntil() == nil else {
            return
        }

        cancelStatusIconPulse()
        let isPaused = scheduler.togglePaused()
        pauseMenuItem?.title = isPaused ? "Resume" : "Pause"
        updateStatusItemIcon()
    }

    @objc private func snoozeThirtyMinutes() {
        _ = hudController.dismissAsSkipped()
        beginSnooze()
    }

    private func beginSnooze() {
        cancelStatusIconPulse()
        scheduler.snooze(for: Self.snoozeDuration)
        refreshSnoozePresentation()
    }

    @objc private func toggleAdaptiveTiming() {
        scheduler.setAdaptiveTimingEnabled(!scheduler.adaptiveTimingEnabled)
        adaptiveTimingMenuItem?.state = scheduler.adaptiveTimingEnabled ? .on : .off
        updateStatusItemIcon()
    }

    @objc private func showStats() {
        statsPanelController.show()
    }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else {
            return
        }

        scheduler.setIntervalMinutes(minutes)
        updateStatusItemIcon()

        for item in intervalMenuItems {
            item.state = item.representedObject as? Int == minutes ? .on : .off
        }
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String else {
            return
        }

        guard rawValue == ThemeSelection.autoRawValue
            || Theme(rawValue: rawValue) != nil
        else {
            return
        }

        selectedThemeRawValue = rawValue
        UserDefaults.standard.set(
            rawValue,
            forKey: Self.selectedThemeDefaultsKey
        )
        hudController.setTheme(
            ThemeSelection.resolve(rawValue: selectedThemeRawValue)
        )

        for item in themeMenuItems {
            item.state = item.representedObject as? String == rawValue ? .on : .off
        }
    }

    private func showHUD() {
        let now = Date()
        hudController.setTheme(
            ThemeSelection.resolve(
                rawValue: selectedThemeRawValue,
                date: now
            )
        )
        hudController.show(
            miniMode: miniModeEnabled,
            nightModeEnabled: nightModeEnabled,
            currentStreak: breakHistoryStore.currentStreak(endingAt: now),
            at: now
        )
    }

    private func showPreWarning() {
        pulseStatusItemIcon()

        guard
            soundEnabled,
            let sound = NSSound(named: NSSound.Name("Tink"))
        else {
            return
        }

        let upcomingBreakDate = scheduler.nextFireDate ?? Date()
        sound.volume = nightModeEnabled
            && Self.isNightTime(at: upcomingBreakDate)
            ? 0
            : 0.03
        sound.play()
    }

    private static func isNightTime(
        at date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 23 || hour < 6
    }

    private func pulseStatusItemIcon() {
        guard
            !isMiniModeBreakActive,
            let button = statusItem?.button
        else {
            return
        }

        statusIconPulseGeneration += 1
        let generation = statusIconPulseGeneration
        isStatusIconPulsing = true
        button.alphaValue = 1
        animateStatusItemPulse(on: button, phase: 0, generation: generation)
    }

    private func animateStatusItemPulse(
        on button: NSStatusBarButton,
        phase: Int,
        generation: Int
    ) {
        guard
            generation == statusIconPulseGeneration,
            statusItem?.button === button,
            phase < 6
        else {
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            button.animator().alphaValue = phase.isMultiple(of: 2) ? 0.3 : 1
        } completionHandler: { [weak self, weak button] in
            guard let self, let button else {
                return
            }

            guard generation == self.statusIconPulseGeneration else {
                self.updateStatusItemIcon()
                return
            }

            let nextPhase = phase + 1

            if nextPhase < 6 {
                self.animateStatusItemPulse(
                    on: button,
                    phase: nextPhase,
                    generation: generation
                )
            } else {
                self.isStatusIconPulsing = false
                self.updateStatusItemIcon()
            }
        }
    }

    private func cancelStatusIconPulse() {
        guard isStatusIconPulsing else {
            return
        }

        statusIconPulseGeneration += 1
        isStatusIconPulsing = false
    }

    private func startMiniModeStatusPresentation() {
        cancelStatusIconPulse()
        isMiniModeBreakActive = true
        miniModeStatusPulseGeneration += 1
        let generation = miniModeStatusPulseGeneration

        guard let button = statusItem?.button else {
            return
        }

        setStatusItemImage(named: "eye.circle.fill", on: button)
        button.alphaValue = 1
        animateMiniModeStatusPulse(
            on: button,
            dimming: true,
            generation: generation
        )
    }

    private func animateMiniModeStatusPulse(
        on button: NSStatusBarButton,
        dimming: Bool,
        generation: Int
    ) {
        guard
            isMiniModeBreakActive,
            generation == miniModeStatusPulseGeneration,
            statusItem?.button === button
        else {
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 1
            button.animator().alphaValue = dimming ? 0.5 : 1
        } completionHandler: { [weak self, weak button] in
            guard
                let self,
                let button,
                self.isMiniModeBreakActive,
                generation == self.miniModeStatusPulseGeneration
            else {
                return
            }

            self.animateMiniModeStatusPulse(
                on: button,
                dimming: !dimming,
                generation: generation
            )
        }
    }

    private func stopMiniModeStatusPresentation() {
        guard isMiniModeBreakActive else {
            return
        }

        isMiniModeBreakActive = false
        miniModeStatusPulseGeneration += 1

        if let button = statusItem?.button {
            button.alphaValue = 1
        }

        updateStatusItemIcon()
    }

    private func startStatusIconTimer() {
        statusIconTimer?.invalidate()
        updateStatusItemIcon()

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateStatusItemIcon()
        }
        RunLoop.main.add(timer, forMode: .common)
        statusIconTimer = timer
    }

    private func updateStatusItemIcon() {
        guard let button = statusItem?.button else {
            return
        }

        guard !isMiniModeBreakActive else {
            return
        }

        guard !isStatusIconPulsing else {
            return
        }

        let symbolName: String

        if scheduler.activeSnoozeUntil() != nil {
            symbolName = "eye.slash"
            button.alphaValue = 0.4
        } else if scheduler.isPaused {
            symbolName = "eye.slash"
            button.alphaValue = 0.4
        } else {
            button.alphaValue = 1

            guard let nextFireDate = scheduler.nextFireDate else {
                setStatusItemImage(named: "eye", on: button)
                return
            }

            let remaining = nextFireDate.timeIntervalSinceNow

            if remaining > 5 * 60 {
                symbolName = "eye"
            } else if remaining >= 2 * 60 {
                symbolName = "eye.fill"
            } else {
                symbolName = "eye.slash"
            }
        }

        setStatusItemImage(named: symbolName, on: button)
    }

    private func refreshSnoozePresentation() {
        if let snoozeUntil = scheduler.activeSnoozeUntil() {
            let time = Self.snoozeTimeFormatter.string(from: snoozeUntil)
            pauseMenuItem?.title = "Snoozed until \(time)"
            pauseMenuItem?.isEnabled = false
        } else {
            pauseMenuItem?.title = scheduler.isPaused ? "Resume" : "Pause"
            pauseMenuItem?.isEnabled = true
        }

        updateStatusItemIcon()
    }

    private func setStatusItemImage(named symbolName: String, on button: NSStatusBarButton) {
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "EyeBreak"
        )
        image?.isTemplate = true
        button.image = image
    }

    @objc private func toggleSound() {
        soundEnabled.toggle()
        UserDefaults.standard.set(
            soundEnabled,
            forKey: Self.soundEnabledDefaultsKey
        )
        hudController.setSoundEnabled(soundEnabled)
        soundMenuItem?.state = soundEnabled ? .on : .off
    }

    @objc private func toggleMiniMode() {
        miniModeEnabled.toggle()
        UserDefaults.standard.set(
            miniModeEnabled,
            forKey: Self.miniModeEnabledDefaultsKey
        )
        miniModeMenuItem?.state = miniModeEnabled ? .on : .off
    }

    @objc private func toggleNightMode() {
        nightModeEnabled.toggle()
        UserDefaults.standard.set(
            nightModeEnabled,
            forKey: Self.nightModeEnabledDefaultsKey
        )
        nightModeMenuItem?.state = nightModeEnabled ? .on : .off
    }

    @objc private func toggleDimScreen() {
        dimScreenEnabled.toggle()
        UserDefaults.standard.set(
            dimScreenEnabled,
            forKey: Self.dimScreenEnabledDefaultsKey
        )
        hudController.setDimScreenEnabled(dimScreenEnabled)
        dimScreenMenuItem?.state = dimScreenEnabled ? .on : .off
    }

    @objc private func toggleCalendarAwareness() {
        calendarAwareEnabled.toggle()
        UserDefaults.standard.set(
            calendarAwareEnabled,
            forKey: Self.calendarAwareEnabledDefaultsKey
        )
        calendarAwareMenuItem?.state = calendarAwareEnabled ? .on : .off

        if calendarAwareEnabled {
            calendarAwareness.requestFullAccess()
        }
    }

    @objc private func toggleEyeExercise() {
        eyeExerciseEnabled.toggle()
        UserDefaults.standard.set(
            eyeExerciseEnabled,
            forKey: Self.eyeExerciseEnabledDefaultsKey
        )
        hudController.setEyeExerciseEnabled(eyeExerciseEnabled)
        eyeExerciseMenuItem?.state = eyeExerciseEnabled ? .on : .off
    }

    @objc private func toggleEscapeShortcut() {
        escapeShortcutEnabled.toggle()
        UserDefaults.standard.set(
            escapeShortcutEnabled,
            forKey: Self.escapeShortcutEnabledDefaultsKey
        )
        hudController.setEscapeShortcutEnabled(escapeShortcutEnabled)

        let state: NSControl.StateValue = escapeShortcutEnabled ? .on : .off
        escapeShortcutMenuItem?.state = state
        escapeShortcutEnabledMenuItem?.state = state
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp

        // This only works for a properly bundled, code-signed app launched
        // from a stable path.
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }

            launchAtLoginMenuItem?.state = service.status == .enabled ? .on : .off
        } catch {
            return
        }
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
