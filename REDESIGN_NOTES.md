# Eyebreaker (EyeBreak) redesign notes

## 1. Purpose

EyeBreak is a macOS menu bar utility that reminds people to rest their eyes using the 20-20-20 rule: at a configurable interval, it presents a short prompt to look at something in the distance. It is aimed at Mac users who spend sustained time at a screen and want a low-friction, configurable reminder that can adapt to idle time, meetings, and presentation contexts.

## 2. Tech stack

- **Language:** Swift 5.
- **UI:** AppKit owns application lifecycle, status-bar menu, windows, panels, screen interaction, and native file dialogs. SwiftUI supplies the HUD card, settings, onboarding, stats, and widget views.
- **Apple frameworks:** SwiftUI, AppKit, Combine, Foundation, CoreGraphics, AVFoundation, Vision, EventKit, ServiceManagement, WidgetKit, UniformTypeIdentifiers, ImageIO, and Darwin.
- **Build:** `build.sh` invokes `swiftc` directly against the macOS SDK (deployment target macOS 14); no Xcode project, Swift Package manifest, or third-party dependency is present. It assembles and ad-hoc signs an `.app` and widget `.appex` bundle. `Scripts/generate_app_icon.swift` draws/packages the icon.
- **Platform:** Native macOS desktop, menu-bar (accessory/agent) app, with a WidgetKit extension. Not a web, iOS, or Android app.
- **Tests:** A shell-driven Swift test executable is described in `README.md` and `test.sh`; `Tests/SystemIdleTimeMonitorTests.swift` is the visible test source.

## 3. User-facing features

- **Scheduled eye breaks:** `BreakScheduler` schedules 20-second break cards at a selected 15, 20, 30, 45, or 60-minute interval. A five-second pre-warning pulses the menu-bar icon and can play a quiet sound. Defaults are 20 minutes and sound enabled.
- **Break card interaction:** The HUD asks the user to look away, counts down, and can be dismissed by clicking/tapping or dragging the card; right-click offers a 30-minute snooze. It has animated entrances/exits, hover/tilt effects, randomized messages and card shapes, and a streak indicator. The card is placed at the top of the selected screen and adapts to displays with a notch.
- **Focus exercise:** When enabled, the break guides the user through far, near (fingertip at arm's length), and far focus phases. It is on by default.
- **Pause and snooze:** The menu can pause/resume reminders or snooze for 30 minutes. Snooze timing is stored, and the status icon communicates active snooze/silent break states.
- **Adaptive timing:** An optional mode samples activity and may advance the break to follow work activity; system sleep, session changes, and idle gaps are accounted for by the scheduler.
- **Idle reset:** Optionally resets the work interval after being away; the configurable threshold is Off, 5, 10, 15, 30, or 60 minutes (10-minute default).
- **Context-aware suppression:** Full-screen activity suppresses reminders. If Screen Recording access already exists, visible window titles can also detect screen-sharing. Optional calendar access skips reminders during an active, non-declined meeting. These checks are local and fail open if their signal is unavailable.
- **Stillness hold:** Optional stillness requirement holds the countdown until the user is no longer actively interacting.
- **Camera attention:** Optional AVFoundation/Vision analysis locally estimates whether the user faces the screen; the countdown is held while they are still facing it. Camera permission is requested only after enabling this setting.
- **Break completion/skip tracking:** Completed and skipped breaks and held time are recorded locally. History is pruned to 30 days; stats show today’s completed count, a seven-day chart, and a selectable daily event timeline. Current streak counts consecutive days with at least one completed break.
- **Themes and night mode:** The HUD supports Auto plus 11 named color themes. Auto varies by time of day. Night mode mutes the pre-warning during night hours and changes the break presentation.
- **Silent mode:** A silent break mode alters the status-bar presentation and avoids audible break cues; silent mode is persisted as a setting.
- **Screen dimming:** Optional display dimming during the break, with prior brightness restored on exit.
- **Settings export/import/reset:** Versioned JSON settings can be exported or imported through native panels. Imports are validated; reset restores defaults. Break history is intentionally not included.
- **Launch at login:** Optional registration via `SMAppService`.
- **First-run onboarding:** Three-page introduction to the rule, how the card works, and the optional permissions/privacy model. Setup itself does not request permissions.
- **Widgets:** Small and medium macOS widgets show today’s completed breaks and current streak; medium also shows seven-day counts. They read a local JSON summary, refresh on a WidgetKit timeline, and do not expose controls.
- **Accessibility shortcut:** Optional global Escape handling to dismiss an active break; enabling it uses macOS Accessibility permission and settings link to the system preference.

## 4. Screens, windows, and menu surfaces

| Surface | What it contains | Implementation |
|---|---|---|
| Menu-bar status item and menu | Eye symbol; Show now, Pause/Resume, Snooze 30 min, Stats, Settings, Quit. Icon may pulse for warning and reflect state. | `Sources/AppDelegate.swift` |
| Break HUD panel | Top-of-screen floating card; countdown, guidance, optional focus exercise, theme, interactions, effects and dismissal. | `Sources/HUDPanelController.swift`, `Sources/HUDView.swift`, `Sources/HUDViewState.swift`, `Sources/Theme.swift`, `Sources/CardShapes.swift`, `Sources/Entrances.swift` |
| Pre-break warning | No separate window or macOS notification: status-item pulse and optional quiet system sound. | `Sources/AppDelegate.swift` |
| Onboarding window | Fixed-size three-page welcome, how-it-works, and permissions pages; Continue/Back/Get started controls. | `Sources/OnboardingWindowController.swift` |
| Settings window | Fixed-size window with Timing, Appearance, Behaviour, and General tabs; live theme preview. | `Sources/SettingsWindowController.swift` |
| Settings reset confirmation | SwiftUI confirmation alert; reset preserves break history. | `Sources/SettingsWindowController.swift` |
| Import/export dialogs and failures | Native open/save panels for JSON and an alert/sheet on transfer errors. | `Sources/SettingsWindowController.swift`, `Sources/SettingsTransfer.swift` |
| Break Stats panel | Floating utility panel with today count, completed/skipped/held legend, weekly chart; selecting a day expands a timeline. | `Sources/StatsPanelController.swift` |
| Accessibility settings handoff | Opens macOS Accessibility privacy settings; not an in-app view. | `Sources/AppDelegate.swift`, `Sources/SettingsWindowController.swift` |
| Small and medium widgets | Today count and streak; medium also has seven-day bars. | `Widget/EyeBreakWidget.swift` |

There is no separate in-app notification center or conventional main window. Reminders are the HUD panel.

## 5. Styling system

- There is no CSS, Tailwind, styled-components, asset catalog, or third-party design system. Views use SwiftUI modifiers and platform-native AppKit controls.
- **Color:** HUD palettes and accents live in `Sources/Theme.swift` as literal RGB/Hue values; stats and widgets use system `Color.accentColor`, `.secondary`, and native window background. Onboarding also uses system accent/secondary colors. Several chart colors and opacity levels are embedded directly in their view files.
- **Typography:** Primarily system fonts (`.headline`, `.caption`, etc.) with selected explicit point sizes and rounded/monospaced designs. No bundled font files or global type scale.
- **Sizing/spacing:** Most dimensions, card geometry, and type sizes are local literals. HUD-specific constants are centralized in `HUDLayout` in `Sources/HUDViewState.swift`; window dimensions are controller constants. Stats, settings and widget dimensions are otherwise specified at point of use.
- **Icons:** SF Symbols via `Image(systemName:)` (e.g. menu eye, settings tab icons, onboarding icons, streak flame); the app icon is programmatically drawn by `Scripts/generate_app_icon.swift`.
- **Existing tokens:** `HUDLayout` constants, `CardHoverHysteresis` thresholds, `Theme` color definitions, and controller content sizes are the main token-like sources. There is no cross-surface spacing/type/color token layer, so standard controls rely on macOS conventions while custom views define their own styles.

## 6. Architecture

- **Entry/lifecycle:** `Sources/main.swift` creates `NSApplication`, assigns `AppDelegate`, and runs the AppKit event loop. `Sources/AppDelegate.swift` initializes defaults, status menu, onboarding, scheduler, and lazily created controllers.
- **UI/logic split:** Screen content is mostly SwiftUI, hosted in AppKit `NSWindow`/`NSPanel` controllers. Scheduling, system integrations, and lifecycle live in controller/service classes. The HUD is especially coordinated: `HUDPanelController` configures/presents the panel and countdown, `HUDViewState` contains presentation state/content selection, and `HUDView` composes custom rendering/animation gestures. Settings sends typed `SettingsChange` cases back through closures to `AppDelegate`.
- **Scheduling/context:** `BreakScheduler` owns timer state, pause/snooze, adaptive activity, and idle reset. It delegates delivery/suppression through closures. `PresentationGuard`, `SystemIdleTimeMonitor`, and `CalendarAwareness` provide context signals; the HUD controller coordinates camera, dimming, sounds, countdown holds, and outcomes.
- **History:** `BreakHistoryStore` is an `ObservableObject` backed by JSON-encoded records in `UserDefaults`. It publishes records and calculates daily counts, streaks, and last-seven-day data. It prunes data beyond 30 days and writes a separate widget summary.
- **Settings/persistence:** Preferences use `UserDefaults.standard`, with SwiftUI `@AppStorage` in the settings view and matching application defaults in `AppDelegate`/`BreakScheduler`. Login status is queried via `SMAppService`. `SettingsTransfer` handles a schema-versioned JSON archive; imported settings are normalized and applied by the app delegate.
- **Widget data flow:** The main app writes `~/Library/Application Support/EyeBreak/widget-summary.json`; the widget reads this summary and computes its own compact statistics. `Widget/EyeBreakWidget.entitlements` grants the extension read-only access.

## 7. Redesign risks and fragile areas

- **HUD presentation is highly coupled to geometry and behavior.** `HUDView.swift`, `HUDViewState.swift`, `HUDPanelController.swift`, `Entrances.swift`, and `CardShapes.swift` coordinate sizes, offsets, screen/notch positioning, hit-testing, gestures, timers, and transitions. Changing card dimensions or hierarchy can break hover thresholds, dragging, animation origins, or screen placement.
- **`Entrances.swift` is a large custom animation implementation.** It contains numerous transitions and pixel/mask choreography; broad edits carry a higher regression risk than ordinary view styling.
- **Custom presentation views contain many hardcoded values.** Theme colors are centralized for the HUD, but typography, spacing, chart colors, opacity, shape radii, window sizes, and widget styles are spread through SwiftUI files. A system-wide visual redesign will need a deliberate shared token layer and decisions on which native controls should remain native.
- **Appearance preference changes have cross-cutting behavior.** Theme, night mode, focus exercise, silent mode, dimming and sounds are applied to live controller/scheduler state as well as persisted preferences. Keep the `SettingsChange`/`AppDelegate.applySettingsChange` path synchronized with the Settings UI.
- **Permissions and privacy messaging depend on behavior.** Camera and calendar prompts are opt-in; Accessibility is required for the global Escape event tap; screen-sharing title inspection only works with pre-existing Screen Recording permission and has no EyeBreak permission toggle. Redesigning copy or controls should preserve these distinctions.
- **Multiple macOS surfaces use different styling conventions.** Settings uses grouped native `Form` controls; stats and widgets use custom SwiftUI; HUD is bespoke. System appearance/accent color may therefore affect some views but not the explicit HUD palette.
- **AppDelegate has broad responsibilities.** It owns status menu behavior, preference application, onboarding choice, scheduling setup, theme resolution and startup registration; UI flow changes can touch this central file and the respective controller.
- **The build script has repository side effects.** `build.sh` stages all changes and attempts a commit and push after building. It should not be run casually during redesign work; this is especially relevant when the requested notes file is untracked.
- **State and UI may need synchronized migration.** Settings are shared between `@AppStorage` and imperative consumers, while history and widget data use separate formats/paths. Renaming defaults keys or changing data shape has compatibility implications.

## Key file map

- `Sources/main.swift` — app entry point.
- `Sources/AppDelegate.swift` — app lifecycle, menu, preference application, onboarding and login item.
- `Sources/BreakScheduler.swift` — reminder and idle/adaptive scheduling.
- `Sources/HUDPanelController.swift`, `Sources/HUDView.swift`, `Sources/HUDViewState.swift` — break panel and view state.
- `Sources/Theme.swift`, `Sources/CardShapes.swift`, `Sources/Entrances.swift` — HUD palettes, shapes and transitions.
- `Sources/SettingsWindowController.swift`, `Sources/SettingsTransfer.swift` — settings surface and import/export.
- `Sources/OnboardingWindowController.swift` — first-run experience.
- `Sources/StatsPanelController.swift`, `Sources/BreakHistoryStore.swift` — history UI and store.
- `Sources/PresentationGuard.swift`, `Sources/SystemIdleTimeMonitor.swift`, `Sources/CalendarAwareness.swift`, `Sources/CameraAttentionDetector.swift`, `Sources/DisplayDimmingController.swift` — system/context integrations.
- `Sources/WidgetSummaryWriter.swift`, `Widget/EyeBreakWidget.swift` — local widget data and UI.
- `build.sh`, `Info.plist`, `Widget/Info.plist`, `Widget/EyeBreakWidget.entitlements` — direct build, app/extension metadata and entitlement setup.
