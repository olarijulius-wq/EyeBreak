# Edge glow break presentation

Edge glow is the default break style. Settings → Appearance → Break style switches between Edge glow and the existing Card, including during a visible break. First-run informational notices retain their card, and silent breaks retain their existing behavior.

## Changed files

| File | Change |
| --- | --- |
| `Sources/BreakStyle.swift` | Edge glow / Card identifiers, names, and default. |
| `Sources/EdgeGlowView.swift` | Cached edge artwork, Core Animation opacity effects, display/notch geometry, and live settings preview. |
| `Sources/EdgeGlowLabel.swift` | Small floating label using DesignSystem typography, spacing, and colors; focus, countdown, and hold-reason text. |
| `Sources/HUDPanelController.swift` | Presentation routing, two nonactivating panels, lifecycle/cleanup, display changes, Reduce Motion updates, and presentation-only hold-reason tracking. |
| `Sources/AppDelegate.swift` | New `breakStyle` default, startup preference, live setting application, and import application. |
| `Sources/SettingsWindowController.swift` | Appearance picker, selected-style preview, AppStorage, refresh, and reset. |
| `Sources/SettingsTransfer.swift` | Optional style archive field, validation, export, and explicit Edge glow fallback for older files. |
| `Tests/EdgeGlowPresentationTests.swift` | Settings migration/roundtrips, label phases/holds, notch geometry, and edge-only texture bounds. |
| `test-edge-glow.sh` | Safe dedicated test runner linking real app types without launching the app. |
| `EDGE_GLOW_REPORT.md` | Implementation, verification, limits, and manual QA. |

The original redesign notes/report and card view, shapes, animations, and state remain unchanged. Scheduling, countdown accounting, permissions, sounds, dimming, suppression, history, widgets, and all existing preference keys/formats retain their existing paths. The only new preference key is `breakStyle`, with values `edgeGlow` and `card`. Settings schema remains version 1 with an optional new field; an older archive selects Edge glow even if Card was selected before importing.

## Rendering and interaction

The screen-sized transparent borderless panel ignores all mouse events. Its AppKit view hosts Core Animation layers with eight cached narrow RGBA textures: four edge strips each for the far and near appearances. A feathered contour is rasterized only when geometry, scale, or theme changes. The center has no glow artwork. No full-screen SwiftUI blur, Canvas, display link, or new countdown timer is used. Layer group opacity is disabled to avoid full-display intermediate opacity surfaces.

Far focus uses a 72pt feather. Near focus crossfades to a brighter 44pt feather. The active atmosphere palette colors the strips. Normal breathing runs between 60% and 100% opacity over 4.5 seconds; night runs at 48% strength over 7 seconds. Held/hover-paused breathing slows to 9 seconds (12 at night). Countdown progress gradually softens the glow across 40 visual steps; repeated calls from the existing timer do not restart animations. Entrance fades over 1 second; dismissal fades over 0.8 seconds. Reduce Motion removes breathing and uses simple opacity fades, with no moving geometry. The existing night-to-Mono theme resolution and Auto time bands are retained.

Display safe-area and auxiliary top-area APIs define the notch, with smooth transitions around its sides and bottom. macOS has no public physical display corner-radius API: notched screens use a conservative 16pt radius, ordinary screens use square logical bounds, and hardware clipping still applies. Exact alignment on other display models needs physical QA.

The second panel contains only a small SwiftUI label, centered beneath the menu bar/notch. It uses micro uppercase metadata plus one instruction/countdown line. Text-only shadows help it remain readable over light applications. Its hosting view updates only when displayed text changes. Clicking dismisses; right-clicking dismisses and requests the existing 30-minute snooze. Hover preserves the card's existing pause behavior, subject to the existing stillness setting. Stillness, camera attention, combined holds, and hover pause have distinct text. Existing Escape and menu actions use the shared dismissal path.

Both panels reject key/main status, use the card's `.statusBar` level and `[.canJoinAllSpaces, .fullScreenAuxiliary]` behavior, and initially use the same mouse-selected screen. A display configuration change repositions the glow/label on the same display ID, with a primary-display fallback after disconnection. Style changes replace only presentation windows; they preserve the countdown, camera session, dimming, and outcome accounting.

## Verification

- Read `REDESIGN_NOTES.md` and `REDESIGN_REPORT.md` first. Inspected `test.sh`; it only compiles/runs tests.
- `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk ./test.sh` passed.
- `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk ./test-edge-glow.sh` passed, including actual settings transfer types, malformed style rejection, both style roundtrips, missing/null-key defaults, phase/hold labels, rounded/notched contour containment, and nonoverlapping edge strips with clear centers at 1x/2x.
- Manually compiled the optimized app and widget with Swift 5, macOS 14 deployment target, the macOS 15 SDK, and the original framework flags. Output is in ignored `.build/edge-glow/`; `build.sh` was never run and no temporary copy of it was needed.
- An isolated native window harness ran with desktop access because the sandbox exposes no displays. On the 1512×982pt built-in screen, it verified the exact full-screen glow frame, a 137×48pt label below the safe area expanding to a single-line 309×48pt near-phase label, click-through/nonactivating window flags, unchanged foreground application, preserved state/timer/end date through Card → Edge glow switching, one skipped callback, and complete window cleanup. It disabled sound, camera, dimming, Accessibility, and history writes.
- Rendered and visually inspected the edge artwork, a synthetic notch, and focus/held text over a light background. Screenshots and temporary harnesses are in ignored `.build/edge-glow/`.
- A synthetic 3008×1692pt @2x render used about 20.5 MB of cached edge images and about 0.29 seconds for initial texture preparation on this host. This is preparation cost, not a live compositor CPU benchmark.
- `git diff --check` passed. No installed app bundle replacement, staging, commit, or push was performed.

## Manual QA checklist

- [ ] **Notched display:** Show now; inspect outer corner alignment and smooth notch flow. Confirm both text lines sit below the notch/menu bar and remain legible over light/dark content.
- [ ] **Non-notched display:** Check all four edges, top label placement, and the untouched center.
- [ ] **External display:** Move the pointer to an external display before Show now. Check correct screen, negative desktop coordinates if applicable, Retina/non-Retina scaling, resolution changes, and disconnect/reconnect cleanup.
- [ ] **Full-screen app:** Check visible presentation through the same allowed/manual path as the old card; confirm scheduled full-screen suppression still behaves as before and typing focus stays in the app.
- [ ] **Multiple Spaces:** Change Spaces during a break; both windows should follow together without activating EyeBreak.
- [ ] **Click-through:** Click, scroll, select, and drag in another app beneath the center and all glow edges. Only the small label should intercept clicks.
- [ ] **Dismiss/snooze:** Click the label, right-click for 30-minute snooze, use Escape with its existing permission/setting, and use the menu actions. Confirm a single outcome and both windows disappearing.
- [ ] **Focus phases:** Watch far 10s → near 5s → far 5s. Check wide/soft versus tight/bright character, matching instructions, countdown softening, and soft exit.
- [ ] **Held countdown:** Exercise stillness, camera, and both together; confirm a frozen count, correct reason, slower pulse, and normal resume. Hover the label with stillness disabled and check the existing pause behavior.
- [ ] **Night mode:** Test during 23:00–06:00; check dimmer/slower Mono glow and existing sound suppression.
- [ ] **Themes:** Try Ember, Ocean, Lavender, Graphite, and Auto; check preview/live colors. Spot-check all eleven themes.
- [ ] **Reduce Motion:** Enable before a break and toggle during one. Check no breathing/movement, simple fades, visible text, and normal completion.
- [ ] **Settings style switch:** Switch Edge glow ↔ Card before and during breaks. Preview should match; remaining time must continue without duplicate sounds, history events, or stranded windows. Confirm reset returns to Edge glow.
- [ ] **Old settings import:** Select Card, then import a version-1 archive without `breakStyle`. Confirm Edge glow is selected and other imported preferences/history behave as before. Export/import both new styles.
- [ ] **Existing integrations:** Check dimming restoration after completion/skip, calendar and screen-sharing suppression, silent mode, and completed/skipped/held history/widget totals.
- [ ] **Activity Monitor:** Compare idle, a full glow break, a held break, and Card on built-in/external displays. Confirm CPU stays low after the brief preparation work and returns to baseline after dismissal; inspect WindowServer as well as EyeBreak.

Physical cross-display/Spaces/full-screen interactions, live permissions, Activity Monitor CPU, and the entire manual matrix have not been completed in this session.
