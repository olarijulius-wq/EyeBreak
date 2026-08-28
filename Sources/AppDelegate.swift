import AppKit
import ServiceManagement

enum ThemeSelection {
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
    static let selectedThemeDefaultsKey = "selectedTheme"
    static let soundEnabledDefaultsKey = "soundEnabled"
    static let focusExerciseEnabledDefaultsKey = "focusExerciseEnabled"
    static let escapeShortcutEnabledDefaultsKey = "escapeShortcutEnabled"
    static let silentModeEnabledDefaultsKey = "silentModeEnabled"
    private static let obsoleteSilentModeDefaultsKey = "miniModeEnabled"
    private static let removedExerciseDefaultsKey = "eyeExerciseEnabled"
    static let nightModeEnabledDefaultsKey = "nightModeEnabled"
    static let dimScreenEnabledDefaultsKey = "dimScreenEnabled"
    static let calendarAwareEnabledDefaultsKey = "calendarAwareEnabled"
    static let requireStillnessEnabledDefaultsKey = "requireStillnessEnabled"
    static let cameraAttentionEnabledDefaultsKey = "cameraAttentionEnabled"
    private static let hasCompletedOnboardingDefaultsKey = "hasCompletedOnboarding"
    private static let snoozeDuration: TimeInterval = 30 * 60

    private static let snoozeTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func loadSilentModePreference(
        from defaults: UserDefaults
    ) -> Bool {
        let storedValue = defaults.object(
            forKey: silentModeEnabledDefaultsKey
        ) as? Bool
        let legacyValue = defaults.object(
            forKey: obsoleteSilentModeDefaultsKey
        ) as? Bool

        if storedValue == nil, let legacyValue {
            defaults.set(legacyValue, forKey: silentModeEnabledDefaultsKey)
        }

        defaults.removeObject(forKey: obsoleteSilentModeDefaultsKey)
        return storedValue ?? legacyValue ?? false
    }

    private var selectedThemeRawValue = ThemeSelection.normalizedRawValue(
        UserDefaults.standard.string(
            forKey: AppDelegate.selectedThemeDefaultsKey
        )
    )
    private var soundEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.soundEnabledDefaultsKey
    ) as? Bool ?? true
    private var focusExerciseEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.focusExerciseEnabledDefaultsKey
    ) as? Bool ?? true
    private var escapeShortcutEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.escapeShortcutEnabledDefaultsKey
    ) as? Bool ?? false
    private var silentModeEnabled = AppDelegate.loadSilentModePreference(
        from: .standard
    )
    private var nightModeEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.nightModeEnabledDefaultsKey
    ) as? Bool ?? true
    private var dimScreenEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.dimScreenEnabledDefaultsKey
    ) as? Bool ?? false
    private var calendarAwareEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.calendarAwareEnabledDefaultsKey
    ) as? Bool ?? false
    private var requireStillnessEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.requireStillnessEnabledDefaultsKey
    ) as? Bool ?? false
    private var cameraAttentionEnabled = UserDefaults.standard.object(
        forKey: AppDelegate.cameraAttentionEnabledDefaultsKey
    ) as? Bool ?? false
    private let breakHistoryStore = BreakHistoryStore()
    private let calendarAwareness = CalendarAwareness()

    private lazy var hudController = HUDPanelController(
        theme: ThemeSelection.resolve(rawValue: selectedThemeRawValue),
        soundEnabled: soundEnabled,
        focusExerciseEnabled: focusExerciseEnabled,
        escapeShortcutEnabled: escapeShortcutEnabled,
        dimScreenEnabled: dimScreenEnabled,
        requireStillnessEnabled: requireStillnessEnabled,
        cameraAttentionEnabled: cameraAttentionEnabled,
        onBreakCompleted: { [weak self] timing in
            self?.breakHistoryStore.recordCompletedBreak(
                heldSeconds: timing.heldSeconds
            )
        },
        onBreakSkipped: { [weak self] timing in
            self?.breakHistoryStore.recordSkippedBreak(
                heldSeconds: timing.heldSeconds
            )
        },
        onSnoozeRequested: { [weak self] in
            self?.beginSnooze()
        },
        onSilentBreakStarted: { [weak self] in
            self?.startSilentModeStatusPresentation()
        },
        onSilentBreakEnded: { [weak self] in
            self?.stopSilentModeStatusPresentation()
        }
    )
    private lazy var statsPanelController = StatsPanelController(
        historyStore: breakHistoryStore
    )
    private lazy var settingsWindowController = SettingsWindowController(
        actions: SettingsActions(
            apply: { [weak self] change in
                self?.applySettingsChange(change)
            },
            showStats: { [weak self] in
                self?.statsPanelController.show()
            },
            openAccessibilitySettings: { [weak self] in
                self?.openAccessibilitySettings()
            },
            exportSettings: { url in
                try SettingsTransfer.export(to: url)
            },
            importSettings: { [weak self] url in
                let importedSettings = try SettingsTransfer.import(from: url)
                self?.applyImportedSettings(importedSettings)
            },
            isLaunchAtLoginEnabled: {
                SMAppService.mainApp.status == .enabled
            },
            setLaunchAtLoginEnabled: { [weak self] isEnabled in
                self?.setLaunchAtLoginEnabled(isEnabled) ?? false
            }
        )
    )
    private lazy var onboardingWindowController = OnboardingWindowController(
        onGetStarted: { [weak self] in
            self?.completeOnboarding()
        }
    )
    private var statusItem: NSStatusItem?
    private var statusIconTimer: Timer?
    private var statusIconPulseGeneration = 0
    private var isStatusIconPulsing = false
    private var silentModeStatusPulseGeneration = 0
    private var isSilentModeBreakActive = false
    private var pauseMenuItem: NSMenuItem?

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
        let defaults = UserDefaults.standard
        let shouldShowOnboarding = shouldShowOnboarding(using: defaults)

        defaults.removeObject(
            forKey: Self.removedExerciseDefaultsKey
        )
        defaults.register(defaults: [
            BreakScheduler.breakIntervalDefaultsKey: BreakScheduler.defaultIntervalMinutes,
            HUDPanelController.breakCountDefaultsKey: 0,
            Self.soundEnabledDefaultsKey: true,
            Self.focusExerciseEnabledDefaultsKey: true,
            Self.escapeShortcutEnabledDefaultsKey: false,
            Self.silentModeEnabledDefaultsKey: false,
            Self.nightModeEnabledDefaultsKey: true,
            Self.dimScreenEnabledDefaultsKey: false,
            Self.calendarAwareEnabledDefaultsKey: false,
            Self.requireStillnessEnabledDefaultsKey: false,
            Self.cameraAttentionEnabledDefaultsKey: false,
            BreakScheduler.adaptiveTimingDefaultsKey: false
        ])
        breakHistoryStore.pruneOlderThan30Days()
        configureStatusItem()

        if shouldShowOnboarding {
            onboardingWindowController.show()
        } else {
            scheduler.start()
        }

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

        menu.addItem(.separator())

        let statsItem = NSMenuItem(
            title: "Stats",
            action: #selector(showStats),
            keyEquivalent: ""
        )
        statsItem.target = self
        menu.addItem(statsItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

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

    @objc private func showStats() {
        statsPanelController.show()
    }

    @objc private func showSettings() {
        settingsWindowController.show()
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
            silentMode: silentModeEnabled,
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
            !isSilentModeBreakActive,
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

    private func startSilentModeStatusPresentation() {
        cancelStatusIconPulse()
        isSilentModeBreakActive = true
        silentModeStatusPulseGeneration += 1
        let generation = silentModeStatusPulseGeneration

        guard let button = statusItem?.button else {
            return
        }

        setStatusItemImage(named: "eye.circle.fill", on: button)
        button.alphaValue = 1
        animateSilentModeStatusPulse(
            on: button,
            dimming: true,
            generation: generation
        )
    }

    private func animateSilentModeStatusPulse(
        on button: NSStatusBarButton,
        dimming: Bool,
        generation: Int
    ) {
        guard
            isSilentModeBreakActive,
            generation == silentModeStatusPulseGeneration,
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
                self.isSilentModeBreakActive,
                generation == self.silentModeStatusPulseGeneration
            else {
                return
            }

            self.animateSilentModeStatusPulse(
                on: button,
                dimming: !dimming,
                generation: generation
            )
        }
    }

    private func stopSilentModeStatusPresentation() {
        guard isSilentModeBreakActive else {
            return
        }

        isSilentModeBreakActive = false
        silentModeStatusPulseGeneration += 1

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

        guard !isSilentModeBreakActive else {
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

    private func applySettingsChange(_ change: SettingsChange) {
        let defaults = UserDefaults.standard

        switch change {
        case .intervalMinutes(let minutes):
            scheduler.setIntervalMinutes(minutes)
            updateStatusItemIcon()

        case .adaptiveTiming(let isEnabled):
            scheduler.setAdaptiveTimingEnabled(isEnabled)
            updateStatusItemIcon()

        case .requireStillness(let isEnabled):
            requireStillnessEnabled = isEnabled
            defaults.set(isEnabled, forKey: Self.requireStillnessEnabledDefaultsKey)
            hudController.setRequireStillnessEnabled(isEnabled)

        case .cameraAttention(let isEnabled):
            cameraAttentionEnabled = isEnabled
            defaults.set(isEnabled, forKey: Self.cameraAttentionEnabledDefaultsKey)
            hudController.setCameraAttentionEnabled(isEnabled)

            guard isEnabled else {
                return
            }

            CameraAttentionDetector.requestPermissionIfNeeded { [weak self] granted in
                guard
                    granted,
                    let self,
                    self.cameraAttentionEnabled
                else {
                    return
                }

                self.hudController.setCameraAttentionEnabled(true)
            }

        case .theme(let rawValue):
            guard rawValue == ThemeSelection.autoRawValue
                || Theme(rawValue: rawValue) != nil
            else {
                return
            }

            selectedThemeRawValue = rawValue
            defaults.set(rawValue, forKey: Self.selectedThemeDefaultsKey)
            hudController.setTheme(
                ThemeSelection.resolve(rawValue: rawValue)
            )

        case .nightMode(let isEnabled):
            nightModeEnabled = isEnabled
            defaults.set(isEnabled, forKey: Self.nightModeEnabledDefaultsKey)

        case .focusExercise(let isEnabled):
            focusExerciseEnabled = isEnabled
            defaults.set(isEnabled, forKey: Self.focusExerciseEnabledDefaultsKey)
            hudController.setFocusExerciseEnabled(isEnabled)

        case .sound(let isEnabled):
            soundEnabled = isEnabled
            defaults.set(isEnabled, forKey: Self.soundEnabledDefaultsKey)
            hudController.setSoundEnabled(isEnabled)

        case .silentMode(let isEnabled):
            silentModeEnabled = isEnabled
            defaults.set(isEnabled, forKey: Self.silentModeEnabledDefaultsKey)

            if !isEnabled {
                _ = hudController.dismissActiveSilentBreakAsSkipped()
            }

        case .dimScreen(let isEnabled):
            dimScreenEnabled = isEnabled
            defaults.set(isEnabled, forKey: Self.dimScreenEnabledDefaultsKey)
            hudController.setDimScreenEnabled(isEnabled)

        case .calendarAwareness(let isEnabled):
            calendarAwareEnabled = isEnabled
            defaults.set(isEnabled, forKey: Self.calendarAwareEnabledDefaultsKey)

            if isEnabled {
                calendarAwareness.requestFullAccess()
            }

        case .escapeShortcut(let isEnabled):
            escapeShortcutEnabled = isEnabled
            defaults.set(isEnabled, forKey: Self.escapeShortcutEnabledDefaultsKey)
            hudController.setEscapeShortcutEnabled(isEnabled)
        }
    }

    private func applyImportedSettings(_ settings: ImportedSettings) {
        if let intervalMinutes = settings.breakIntervalMinutes {
            applySettingsChange(.intervalMinutes(intervalMinutes))
        }

        if let adaptiveTimingEnabled = settings.adaptiveTimingEnabled {
            applySettingsChange(.adaptiveTiming(adaptiveTimingEnabled))
        }

        if let snoozeUntil = settings.snoozeUntil {
            scheduler.setImportedSnoozeUntil(snoozeUntil)
        }

        if let requireStillnessEnabled = settings.requireStillnessEnabled {
            applySettingsChange(.requireStillness(requireStillnessEnabled))
        }

        if let cameraAttentionEnabled = settings.cameraAttentionEnabled {
            applySettingsChange(.cameraAttention(cameraAttentionEnabled))
        }

        if let selectedTheme = settings.selectedTheme {
            applySettingsChange(.theme(selectedTheme))
        }

        if let nightModeEnabled = settings.nightModeEnabled {
            applySettingsChange(.nightMode(nightModeEnabled))
        }

        if let focusExerciseEnabled = settings.focusExerciseEnabled {
            applySettingsChange(.focusExercise(focusExerciseEnabled))
        }

        if let soundEnabled = settings.soundEnabled {
            applySettingsChange(.sound(soundEnabled))
        }

        if let silentModeEnabled = settings.silentModeEnabled {
            applySettingsChange(.silentMode(silentModeEnabled))
        }

        if let dimScreenEnabled = settings.dimScreenEnabled {
            applySettingsChange(.dimScreen(dimScreenEnabled))
        }

        if let calendarAwareEnabled = settings.calendarAwareEnabled {
            applySettingsChange(.calendarAwareness(calendarAwareEnabled))
        }

        if let escapeShortcutEnabled = settings.escapeShortcutEnabled {
            applySettingsChange(.escapeShortcut(escapeShortcutEnabled))
        }

        scheduler.reschedule()
        refreshSnoozePresentation()
        updateStatusItemIcon()
    }

    private func setLaunchAtLoginEnabled(_ isEnabled: Bool) -> Bool {
        let service = SMAppService.mainApp

        // This only works for a properly bundled, code-signed app launched
        // from a stable path.
        do {
            if isEnabled, service.status != .enabled {
                try service.register()
            } else if !isEnabled, service.status != .notRegistered {
                try service.unregister()
            }
        } catch {
            return service.status == .enabled
        }

        return service.status == .enabled
    }

    private func shouldShowOnboarding(using defaults: UserDefaults) -> Bool {
        !defaults.bool(forKey: Self.hasCompletedOnboardingDefaultsKey)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(
            true,
            forKey: Self.hasCompletedOnboardingDefaultsKey
        )
        startSchedulerIfNeeded()

        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusItem?.button else {
                return
            }

            NSApp.activate(ignoringOtherApps: true)
            button.performClick(nil)
        }
    }

    private func startSchedulerIfNeeded() {
        guard !scheduler.isPaused, scheduler.nextFireDate == nil else {
            updateStatusItemIcon()
            return
        }

        scheduler.start()
        updateStatusItemIcon()
    }

    private func openAccessibilitySettings() {
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
