import AppKit
import Combine
import SwiftUI

enum SettingsChange {
    case intervalMinutes(Int)
    case adaptiveTiming(Bool)
    case requireStillness(Bool)
    case cameraAttention(Bool)
    case theme(String)
    case nightMode(Bool)
    case focusExercise(Bool)
    case sound(Bool)
    case silentMode(Bool)
    case dimScreen(Bool)
    case calendarAwareness(Bool)
    case escapeShortcut(Bool)
}

struct SettingsActions {
    let apply: (SettingsChange) -> Void
    let showStats: () -> Void
    let openAccessibilitySettings: () -> Void
    let isLaunchAtLoginEnabled: () -> Bool
    let setLaunchAtLoginEnabled: (Bool) -> Bool
}

private final class SettingsWindowViewModel: ObservableObject {
    @Published private(set) var launchAtLoginEnabled: Bool

    private let readLaunchAtLoginEnabled: () -> Bool
    private let writeLaunchAtLoginEnabled: (Bool) -> Bool

    init(actions: SettingsActions) {
        readLaunchAtLoginEnabled = actions.isLaunchAtLoginEnabled
        writeLaunchAtLoginEnabled = actions.setLaunchAtLoginEnabled
        launchAtLoginEnabled = actions.isLaunchAtLoginEnabled()
    }

    func refreshLaunchAtLogin() {
        launchAtLoginEnabled = readLaunchAtLoginEnabled()
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        launchAtLoginEnabled = writeLaunchAtLoginEnabled(isEnabled)
    }
}

final class SettingsWindowController: NSWindowController {
    static let contentSize = NSSize(width: 480, height: 520)

    private let viewModel: SettingsWindowViewModel

    init(actions: SettingsActions) {
        let viewModel = SettingsWindowViewModel(actions: actions)
        self.viewModel = viewModel

        let settingsWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "EyeBreak Settings"
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.isExcludedFromWindowsMenu = false
        settingsWindow.contentMinSize = Self.contentSize
        settingsWindow.contentMaxSize = Self.contentSize
        settingsWindow.tabbingMode = .disallowed
        settingsWindow.animationBehavior = .documentWindow

        super.init(window: settingsWindow)
        shouldCascadeWindows = false

        settingsWindow.contentViewController = NSHostingController(
            rootView: SettingsView(
                actions: actions,
                viewModel: viewModel
            )
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else {
            return
        }

        viewModel.refreshLaunchAtLogin()

        if !window.isVisible {
            window.center()
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @AppStorage(BreakScheduler.breakIntervalDefaultsKey)
    private var intervalMinutes = BreakScheduler.defaultIntervalMinutes
    @AppStorage(BreakScheduler.adaptiveTimingDefaultsKey)
    private var adaptiveTimingEnabled = false
    @AppStorage(AppDelegate.requireStillnessEnabledDefaultsKey)
    private var requireStillnessEnabled = false
    @AppStorage(AppDelegate.cameraAttentionEnabledDefaultsKey)
    private var cameraAttentionEnabled = false

    @AppStorage(AppDelegate.selectedThemeDefaultsKey)
    private var selectedThemeRawValue = Theme.graphite.rawValue
    @AppStorage(AppDelegate.nightModeEnabledDefaultsKey)
    private var nightModeEnabled = true
    @AppStorage(AppDelegate.focusExerciseEnabledDefaultsKey)
    private var focusExerciseEnabled = true

    @AppStorage(AppDelegate.soundEnabledDefaultsKey)
    private var soundEnabled = true
    @AppStorage(AppDelegate.silentModeEnabledDefaultsKey)
    private var silentModeEnabled = false
    @AppStorage(AppDelegate.dimScreenEnabledDefaultsKey)
    private var dimScreenEnabled = false
    @AppStorage(AppDelegate.calendarAwareEnabledDefaultsKey)
    private var calendarAwareEnabled = false
    @AppStorage(AppDelegate.escapeShortcutEnabledDefaultsKey)
    private var escapeShortcutEnabled = false

    @State private var isShowingResetConfirmation = false

    private let actions: SettingsActions
    @ObservedObject private var viewModel: SettingsWindowViewModel

    init(
        actions: SettingsActions,
        viewModel: SettingsWindowViewModel
    ) {
        self.actions = actions
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        TabView {
            timingTab
                .tabItem {
                    Label("Timing", systemImage: "clock")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }

            behaviourTab
                .tabItem {
                    Label("Behaviour", systemImage: "switch.2")
                }

            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
        }
        .padding(20)
        .frame(
            width: SettingsWindowController.contentSize.width,
            height: SettingsWindowController.contentSize.height
        )
        .onAppear {
            viewModel.refreshLaunchAtLogin()

            if !BreakScheduler.supportedIntervalMinutes.contains(intervalMinutes) {
                intervalMinutes = BreakScheduler.defaultIntervalMinutes
            }

            let normalizedTheme = ThemeSelection.normalizedRawValue(
                selectedThemeRawValue
            )
            if normalizedTheme != selectedThemeRawValue {
                selectedThemeRawValue = normalizedTheme
            }
        }
        .onChange(of: intervalMinutes) { _, newValue in
            actions.apply(.intervalMinutes(newValue))
        }
        .onChange(of: adaptiveTimingEnabled) { _, newValue in
            actions.apply(.adaptiveTiming(newValue))
        }
        .onChange(of: requireStillnessEnabled) { _, newValue in
            actions.apply(.requireStillness(newValue))
        }
        .onChange(of: cameraAttentionEnabled) { _, newValue in
            actions.apply(.cameraAttention(newValue))
        }
        .onChange(of: selectedThemeRawValue) { _, newValue in
            actions.apply(.theme(newValue))
        }
        .onChange(of: nightModeEnabled) { _, newValue in
            actions.apply(.nightMode(newValue))
        }
        .onChange(of: focusExerciseEnabled) { _, newValue in
            actions.apply(.focusExercise(newValue))
        }
        .onChange(of: soundEnabled) { _, newValue in
            actions.apply(.sound(newValue))
        }
        .onChange(of: silentModeEnabled) { _, newValue in
            actions.apply(.silentMode(newValue))
        }
        .onChange(of: dimScreenEnabled) { _, newValue in
            actions.apply(.dimScreen(newValue))
        }
        .onChange(of: calendarAwareEnabled) { _, newValue in
            actions.apply(.calendarAwareness(newValue))
        }
        .onChange(of: escapeShortcutEnabled) { _, newValue in
            actions.apply(.escapeShortcut(newValue))
        }
        .alert("Reset all settings?", isPresented: $isShowingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This restores every EyeBreak setting to its default value. Your break stats are kept.")
        }
    }

    private var timingTab: some View {
        Form {
            Section("Break schedule") {
                Picker("Interval", selection: $intervalMinutes) {
                    ForEach(BreakScheduler.supportedIntervalMinutes, id: \.self) {
                        Text("\($0) minutes").tag($0)
                    }
                }

                Toggle("Adaptive timing", isOn: $adaptiveTimingEnabled)
                Toggle("Require stillness", isOn: $requireStillnessEnabled)
                Toggle("Camera attention", isOn: $cameraAttentionEnabled)
            }
        }
        .formStyle(.grouped)
    }

    private var appearanceTab: some View {
        Form {
            Section("Break card") {
                Picker("Theme", selection: $selectedThemeRawValue) {
                    Text("Auto").tag(ThemeSelection.autoRawValue)

                    ForEach(Theme.allCases, id: \.rawValue) { theme in
                        Text(theme.displayName).tag(theme.rawValue)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Live preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(previewTheme.background)
                        .frame(height: 84)
                        .overlay {
                            Text(previewTheme.displayName)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .shadow(radius: 3)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.18), lineWidth: 1)
                        }
                }
                .padding(.vertical, 4)

                Toggle("Night mode", isOn: $nightModeEnabled)
                Toggle("Focus exercise", isOn: $focusExerciseEnabled)
            }
        }
        .formStyle(.grouped)
    }

    private var behaviourTab: some View {
        Form {
            Section("Break behaviour") {
                Toggle("Sound", isOn: $soundEnabled)
                Toggle("Silent mode", isOn: $silentModeEnabled)
                Toggle("Dim screen", isOn: $dimScreenEnabled)
                Toggle("Skip during meetings", isOn: $calendarAwareEnabled)
                Toggle("Escape shortcut", isOn: $escapeShortcutEnabled)
            }

            Section("Accessibility") {
                Button("Open Accessibility Settings…") {
                    actions.openAccessibilitySettings()
                }
                .buttonStyle(.link)
            }
        }
        .formStyle(.grouped)
    }

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
            }

            Section("Break history") {
                Button("Show Stats…") {
                    actions.showStats()
                }
            }

            Section("Defaults") {
                Button("Reset All Settings…", role: .destructive) {
                    isShowingResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
    }

    private var previewTheme: Theme {
        ThemeSelection.resolve(rawValue: selectedThemeRawValue)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.launchAtLoginEnabled
            },
            set: { requestedValue in
                viewModel.setLaunchAtLogin(requestedValue)
            }
        )
    }

    private func resetAllSettings() {
        intervalMinutes = BreakScheduler.defaultIntervalMinutes
        adaptiveTimingEnabled = false
        requireStillnessEnabled = false
        cameraAttentionEnabled = false

        selectedThemeRawValue = Theme.graphite.rawValue
        nightModeEnabled = true
        focusExerciseEnabled = true

        soundEnabled = true
        silentModeEnabled = false
        dimScreenEnabled = false
        calendarAwareEnabled = false
        escapeShortcutEnabled = false

        viewModel.setLaunchAtLogin(false)
    }
}
