# EyeBreak

EyeBreak is a menu-bar app for macOS 14 and later. It implements the 20-20-20 rule: every 20 minutes, look at something about 20 feet away for 20 seconds. At each interval it presents a break card at the top of the screen.

## Features

- Reminder intervals of 15, 20, 30, 45, or 60 minutes, with a five-second warning.
- Twenty-second regular breaks and a two-minute break after every fourth completed break.
- Pause, 30-minute snooze, adaptive timing, idle detection, and full-screen suppression.
- Sound, silent mode, screen dimming, themes, night mode, and an optional focus exercise.
- Optional stillness, camera-attention, meeting-awareness, and global Escape-key controls.
- Local 30-day break history, seven-day statistics, streaks, and small or medium widgets.
- Versioned JSON settings export and import. Break history and accumulated break counts are not included.
- Optional launch at login.

## Build from source

The build uses Apple Command Line Tools directly. It does not require an Xcode project, Swift package dependencies, or third-party tools. Install the Command Line Tools and build with:

```sh
xcode-select --install
git clone https://github.com/olarijulius-wq/EyeBreak.git
cd EyeBreak
./build.sh
```

The script builds for the Mac's current architecture, targets macOS 14, assembles the app and widget, ad-hoc signs both, and verifies the resulting signatures. The output is `EyeBreak.app` in the repository root.

The current build script also stages repository changes, attempts a timestamped Git commit, and attempts to push the current branch. Use a clean checkout if those Git operations should have nothing to commit.

## Install and launch at login

After building, copy the app to `/Applications` and open it:

```sh
sudo ditto EyeBreak.app /Applications/EyeBreak.app
open /Applications/EyeBreak.app
```

To enable launch at login:

1. Open the EyeBreak menu-bar menu and choose **Settings…**.
2. Open the **General** tab.
3. Enable **Launch at login**.

Install and open the app from `/Applications` before enabling the login item. macOS login-item registration expects the signed app bundle to remain at a stable path.

## Permissions and privacy

All permission-dependent settings are off by default, and setup requests no permissions. EyeBreak has no network integration; settings, history, calendar checks, camera analysis, and widget data remain on the Mac.

- **Camera** enables Camera attention. EyeBreak uses AVFoundation and Vision locally to hold the break countdown while the user is still facing the screen. Access is requested only when Camera attention is enabled.
- **Calendars** enables Skip during meetings. EyeBreak checks for a meeting in progress and suppresses the reminder while that meeting is active. Access is requested only when this setting is enabled.
- **Accessibility** enables the global Escape shortcut for dismissing an active break card. The setting is off by default; the Behaviour tab includes a link to the relevant macOS privacy settings.
- **Screen Recording** is not requested and has no EyeBreak setting. If the permission has already been granted, EyeBreak can inspect visible window names to detect an active screen-sharing session and suppress a reminder. Without it, screen-sharing detection is unavailable; other presentation checks still work.

## Project structure

- `Sources/main.swift` — Creates the application, installs its delegate, and starts the AppKit event loop.
- `Sources/AppDelegate.swift` — Owns lifecycle, menu-bar commands, settings application, scheduling, history, onboarding, and login-item registration.
- `Sources/BreakHistoryStore.swift` — Persists 30 days of completed and skipped breaks and calculates daily summaries and streaks.
- `Sources/BreakScheduler.swift` — Schedules reminders, warnings, pause and snooze state, adaptive timing, and suppression checks.
- `Sources/CalendarAwareness.swift` — Requests calendar access and checks whether a meeting is in progress.
- `Sources/CameraAttentionDetector.swift` — Uses AVFoundation and Vision to estimate locally whether the user is facing the display.
- `Sources/DisplayDimmingController.swift` — Dims displays during a break and restores their previous brightness.
- `Sources/HUDPanelController.swift` — Manages the break panel, countdown, input, sound, dimming, camera holds, and Escape handling.
- `Sources/HUDView.swift` — Defines the SwiftUI break card, themes, messages, focus exercise, layouts, and animations.
- `Sources/OnboardingWindowController.swift` — Presents the first-run explanation and privacy information.
- `Sources/PresentationGuard.swift` — Detects full-screen or screen-sharing presentation state and reads recent input activity.
- `Sources/SettingsTransfer.swift` — Encodes, validates, imports, and exports versioned settings files.
- `Sources/SettingsWindowController.swift` — Presents the Timing, Appearance, Behaviour, and General settings tabs.
- `Sources/StatsPanelController.swift` — Displays seven-day counts, held time, streaks, and daily event timelines.
- `Sources/WidgetSummaryWriter.swift` — Writes a local summary of completed breaks for the widget.
- `Widget/EyeBreakWidget.swift` — Reads the summary and renders the small and medium widgets.
- `Scripts/generate_app_icon.swift` — Draws the app icon and provides an ICNS packaging fallback.

Supporting files:

- `Info.plist` — Defines the main app bundle, deployment target, and camera and calendar usage descriptions.
- `Widget/Info.plist` — Defines the WidgetKit extension bundle.
- `Widget/EyeBreakWidget.entitlements` — Sandboxes the widget and grants read-only access to its local summary.
- `build.sh` — Compiles, assembles, ad-hoc signs, and verifies the app and widget bundles.

## Signing and Gatekeeper

`build.sh` ad-hoc signs the app and widget. It does not use an Apple Developer ID certificate, enable a trusted developer identity, or submit the app to Apple's notary service.

A copy built locally should run on the Mac that built it. A copy received from someone else may be blocked by Gatekeeper because macOS cannot identify its developer or verify Apple notarization. Only if the source and the copy are trusted, try opening it once and then use **System Settings → Privacy & Security → Open Anyway**. Managed Macs may not permit that override. Apple documents the current procedure in [Open a Mac app from an unknown developer](https://support.apple.com/guide/mac-help/mh40616/mac).
