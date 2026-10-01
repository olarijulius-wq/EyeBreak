# EyeBreak visual redesign

The custom UI now uses warm, dark atmosphere, light system typography, white glow rings, and quiet underlined selection. Native settings forms and the native menu remain native. The supplied text brief and REDESIGN_NOTES.md were the reference; no screenshot attachment was available.

## Changed files and surfaces

| File | Change |
| --- | --- |
| Sources/DesignSystem.swift | New shared colors, typography, spacing, radii, Canvas atmosphere, GlowRing, GlowSelection, DayStrip, MicroLabel. Compiles in both targets. |
| Sources/Theme.swift | Eleven dark atmosphere palettes; removed obsolete gradient/foreground/accent styling. Raw theme identifiers and Auto hour bands are unchanged. |
| Sources/HUDView.swift | Uppercase randomized headlines, eye-break metadata, quiet subtitles/streak, countdown ring and remaining arc, Far/Near/Far labels with soft active glow. Hover copy and gesture callbacks retained. |
| Sources/HUDViewState.swift | Taller card geometry and uppercase SF Light text measurement; removed obsolete accent calculation. Scheduling, duration, hold/phase state, random selection and countdown logic unchanged. |
| Sources/CardShapes.swift | All six shape cases retained, with continuous rounded contours and softened tips. |
| Sources/Entrances.swift | Existing transitions and timing retained; reduced transform amplitudes, removed card border/exterior glow, added a Reduce Motion fade path. No broad rewrite. |
| Sources/OnboardingWindowController.swift | Full-bleed atmosphere, large two-line headings, original body/privacy paragraphs, glow-ring arrow and underlined page indicators. Same actions and permission flow. |
| Sources/StatsPanelController.swift | Light 64pt count, warm-white completed / grey skipped / rust held chart marks, shared day strip, and a quiet scrollable event list. Same day selection and history reads. |
| Sources/SettingsWindowController.swift | Dark Aqua, warm amber tint, light tab symbols, native Forms and an atmospheric live preview. All bindings, SettingsChange callbacks and transfer/reset actions preserved. |
| Widget/EyeBreakWidget.swift | Static atmosphere, 56pt light count, TODAY/STREAK labels, medium-size weekly bars/day strip. Provider, decoding, refresh and data format unchanged. |
| Sources/AppDelegate.swift | Presentation-only edit: central status-image helper applies 16pt light SF Symbol configuration, including initial setup. Existing symbol choices/pulse/snooze/silent logic preserved. |
| Scripts/generate_app_icon.swift | Optional warm glowing orb icon on near-black; existing PNG/ICNS packaging retained. |
| build.sh | Adds Sources/DesignSystem.swift to widget compiler inputs. Script was not run. |
| REDESIGN_REPORT.md | This handoff, tokens, verification and manual QA checklist. |

The pre-existing untracked REDESIGN_NOTES.md was read and left untouched. No files carrying behavior were deleted. No commits, staging, pushes or installation were performed.

## Final tokens

| Token | Value |
| --- | --- |
| Base | #050303 |
| Primary text | #F2EEE9 |
| Secondary text | #FFFFFF at 55% |
| Tertiary marks | #FFFFFF at 35%; decorative, not small meaningful text |
| Glow | #FFFFFF |
| Amber / native settings tint | #D9AA72 |
| Rust / held indicator | #A85D44 |
| Display type | SF system, 40pt light, tracking -1.2pt |
| Metadata | SF system, 12pt regular, tracking 0 |
| Micro label | SF system, 10pt regular, tracking 1.8pt, uppercase |
| Surface type variants | Stats count 64pt light/-2pt; widget count 56pt light/-1.8pt; HUD countdown 24pt light; onboarding body 13pt regular |
| Spacing | 4, 8, 12, 16, 24, 32, 48pt |
| Shared radii | Card 28pt; control 12pt; HUD contours scale with card height |
| Ring | Default 56pt diameter, 1.5pt stroke; onboarding arrow 52pt |
| Ring bloom | White 22%, 4.5pt stroke blurred 5pt |
| Ring track / progress | White 22% / 95%; plain ring 85% |
| Selection glow | White 12% to clear, radius 36pt in a 72pt square field |
| Day strip | 10pt letters, 12×1pt underline; optional 3pt bars, 2–36pt tall |
| Atmosphere | Three radial fields per theme, intensity 0.80, 32-second drift, maximum 12fps |
| Night atmosphere | Black base, intensity 0.384 (0.80×0.48), 40-second drift; existing night-to-mono selection retained |
| Text scrim | Black opacity 52% at top, 58% at 30% height, 88% at 72%, 100% at bottom |
| Reduce Motion | Static atmosphere, 0.2-second HUD fade, no tilt/hover growth/drag rebound/count-number movement; entrance stays on fade path if the preference changes mid-break |
| Widget atmosphere | Always static |

All named themes share #050303 as the base:

| Identifier | Blob colors |
| --- | --- |
| graphite | #8D7461, #514442, #766A4D |
| sage | #79815A, #3F5744, #8C693D |
| peach | #C68B65, #8C4736, #9E7843 |
| lavender | #887089, #563E64, #9A694E |
| ocean | #527E82, #244653, #82704C |
| midnight | #4D526E, #302C4C, #706048 |
| ember | #C67A3E, #7A2E1C, #7D6A35 |
| matcha | #92925C, #4E603D, #9A7644 |
| frost | #809493, #4C6270, #9A8164 |
| dusk | #A16A70, #60394F, #AA7846 |
| mono | #716960, #403B39, #59544C |

Auto keeps its original mapping: 05–09 frost, 09–12 matcha, 12–16 sage, 16–19 peach, 19–22 dusk, otherwise midnight. Night activation remains 23–06 when enabled.

## HUD geometry and behavior review

Card heights are standard 176pt, wide 164pt, compact 208pt. Width limits and variants remain unchanged: standard preferred 460 / maximum 600, wide 600, compact 320. Panel is 780×464pt. Increasing the panel preserves space for the taller cards and full drag travel.

The hover tracking padding 16pt, exit hysteresis 20pt, tilt edge 8pt, drag activation 3pt, downward rubber-band maximum 120pt, and upward maximum -20pt remain unchanged. Card top origins remain 40pt for notched displays and 12pt for non-notched displays. Existing panel placement, right-click silhouette lookup, entrance masks and pixel grids derive their dimensions from HUDLayout/state.cardSize; no HUDPanelController edit was needed. Geometry assertions checked entry/exit boundaries, shape centers and the drag envelope for all three sizes.

The current code's drag gesture rubber-bands and returns; it did not dismiss before this redesign. That behavior was preserved despite the notes describing drag dismissal. Clicking dismisses, and right-clicking offers snooze.

## Verification

- Inspected test.sh before running; it only builds/runs tests. `./test.sh` passed (`SystemIdleTimeMonitorTests passed`).
- Manually compiled the app and widget using swiftc, Swift 5, optimization and macOS 14 deployment target with their original framework flags. Shared DesignSystem compiled in both targets.
- Used `/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk` for final compilation. The installed Xcode 27 SDK's new SwiftUI macro subprocess could not start inside the tool sandbox; the stable SDK compiled successfully without changing source to work around it. Widget also compiled with the default SDK.
- Compiled the icon generator and rendered the PNG.
- Rendered and visually inspected native SwiftUI HUD variants (including all six silhouettes, long compact title, near phase, held and night), all three onboarding pages, settings preview/forms, populated/empty/expanded stats, and both widget sizes.
- NSHostingView capture verified native Form and ScrollView contents that ImageRenderer cannot draw. Real WidgetKit hosting was simulated with 16pt host insets; the actual desktop widget remains a manual check.
- Estimated secondary text contrast under ordinary sRGB composition across all palettes, 36 drift phases, 6 aspect ratios and sampled positions: minimum approximately 4.67:1. This is an analytical check, not a complete runtime accessibility audit.
- `git diff --check` passed. Reviewed persistence keys, Auto bands, permission copy and widget data/provider code for unchanged behavior.

Snapshots and temporary verification executables are in the ignored `.build/redesign` directory. The current installed app bundle was not replaced. Physical display behavior, live permissions, import/export roundtrips and real WidgetKit hosting have not been exercised in this session.

## Manual QA checklist

- [ ] Trigger a break on notched and non-notched displays; check top placement, all card sizes, hover edges and entrance/exit clipping.
- [ ] Drag down/up and release (existing spring-back), click to dismiss, right-click and snooze 30 minutes; verify the menu state and Escape dismissal when enabled.
- [ ] Run the full far 10s / near 5s / far 5s exercise; check held/paused states and remaining-time arc.
- [ ] Inspect all 11 themes and Auto; verify night mode is deeper/dimmer and preserves sound suppression.
- [ ] Enable Reduce Motion before a break and toggle it during a break; verify static blobs, fade presentation and no vanished card.
- [ ] Complete onboarding with Continue/Back/Get started; confirm original permission/privacy statements and no setup permission prompts.
- [ ] Select/deselect every stats day, scroll populated timelines and inspect empty days.
- [ ] Add both widget sizes in the real desktop host; compare counts/streak to stats and verify refresh.
- [ ] Exercise settings tabs and live theme/focus/night preview; export/import settings and reset, confirming settings synchronization and retained history.
- [ ] Verify menu warning pulse, pause, snooze and silent-mode indications.
