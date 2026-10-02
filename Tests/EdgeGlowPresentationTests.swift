import AppKit

@main
private struct EdgeGlowPresentationTests {
    static func main() throws {
        try verifySettingsCompatibility()
        verifyLabelGuidance()
        verifyScreenGeometry()
        print("EdgeGlowPresentationTests passed")
    }

    private static func verifySettingsCompatibility() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EyeBreak-EdgeGlowTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let archive = directory.appendingPathComponent("settings.json")
        let suite = "EyeBreak.EdgeGlowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }

        func writeArchive(_ settings: [String: Any]) throws {
            let object: [String: Any] = [
                "schemaVersion": 1,
                "appVersion": "1.0",
                "settings": settings
            ]
            try JSONSerialization.data(withJSONObject: object).write(to: archive)
        }

        // A pre-glow archive must choose the new default, including on an
        // installation that currently prefers Card. Existing fields survive.
        defaults.set(BreakStyle.card.rawValue, forKey: AppDelegate.breakStyleDefaultsKey)
        try writeArchive([
            "breakIntervalMinutes": 30,
            "selectedTheme": "peach",
            "requireStillnessEnabled": true
        ])
        let legacy = try SettingsTransfer.import(from: archive)
        precondition(legacy.breakStyle == BreakStyle.edgeGlow.rawValue)
        precondition(legacy.breakIntervalMinutes == 30)
        precondition(legacy.selectedTheme == "peach")
        precondition(legacy.requireStillnessEnabled == true)
        defaults.set(legacy.breakStyle, forKey: AppDelegate.breakStyleDefaultsKey)
        precondition(defaults.string(forKey: AppDelegate.breakStyleDefaultsKey) == "edgeGlow")

        for style in BreakStyle.allCases {
            defaults.set(style.rawValue, forKey: AppDelegate.breakStyleDefaultsKey)
            try SettingsTransfer.export(to: archive, defaults: defaults)
            let imported = try SettingsTransfer.import(from: archive)
            precondition(imported.breakStyle == style.rawValue)
        }

        defaults.removeObject(forKey: AppDelegate.breakStyleDefaultsKey)
        try SettingsTransfer.export(to: archive, defaults: defaults)
        let absentPreference = try SettingsTransfer.import(from: archive)
        precondition(absentPreference.breakStyle == "edgeGlow")

        defaults.set("unrecognized", forKey: AppDelegate.breakStyleDefaultsKey)
        try SettingsTransfer.export(to: archive, defaults: defaults)
        let invalidPreference = try SettingsTransfer.import(from: archive)
        precondition(invalidPreference.breakStyle == "edgeGlow")

        for invalid: Any in ["unrecognized", 123, false, ["card"]] {
            try writeArchive(["breakStyle": invalid])
            var rejected = false
            do {
                _ = try SettingsTransfer.import(from: archive)
            } catch {
                rejected = true
            }
            precondition(rejected, "Invalid break style accepted: \(invalid)")
        }

        try writeArchive(["breakStyle": NSNull()])
        let nullPreference = try SettingsTransfer.import(from: archive)
        precondition(nullPreference.breakStyle == "edgeGlow")
    }

    private static func verifyLabelGuidance() {
        let state = HUDViewState(
            theme: .ember,
            duration: HUDViewState.regularDuration,
            focusExerciseEnabled: true,
            currentStreak: 0,
            isNightMode: false,
            isSilentMode: false,
            screenHasNotch: true,
            date: Date(timeIntervalSince1970: 0),
            calendar: Calendar(identifier: .gregorian),
            frontmostApplicationBundleIdentifier: nil,
            messageOverride: (title: "Eye break", subtitle: "Look across the room")
        )

        func label(_ reason: EdgeGlowHoldReason? = nil) -> EdgeGlowLabelContent {
            EdgeGlowLabelContent(state: state, holdReason: reason)
        }

        precondition(label().microLabel == "Focus exercise")
        precondition(label().instruction == "LOOK FAR AWAY · 20")
        state.remainingSeconds = 10.01
        precondition(label().instruction == "LOOK FAR AWAY · 11")
        state.remainingSeconds = 10
        precondition(label().instruction == "FOCUS ON YOUR FINGERTIP AT ARM’S LENGTH · 10")
        state.remainingSeconds = 5.01
        precondition(label().instruction.hasPrefix("FOCUS ON YOUR FINGERTIP"))
        state.remainingSeconds = 5
        precondition(label().instruction == "LOOK FAR AWAY AGAIN · 5")

        state.isHeld = true
        precondition(label(.camera).microLabel == "Waiting for your gaze")
        precondition(label(.camera).instruction == "LOOK AWAY FROM THE SCREEN · 5")
        precondition(label(.stillness).microLabel == "Waiting for stillness")
        precondition(label(.stillness).instruction == "REST YOUR HANDS · 5")
        precondition(label(.stillnessAndCamera).instruction == "HANDS OFF & LOOK AWAY · 5")
        precondition(label().instruction == label(.stillness).instruction)
        precondition(state.remainingSeconds == 5, "Presentation must not mutate the countdown")

        state.isHeld = false
        state.isPaused = true
        precondition(label().instruction == "MOVE AWAY TO CONTINUE · 5")
        state.isPaused = false
        state.focusExerciseEnabled = false
        precondition(label().microLabel == "Eye break")
        precondition(label().instruction == "LOOK ACROSS THE ROOM · 5")

        state.remainingSeconds = 0
        precondition(label().instruction.hasSuffix(" · 0"))
    }

    private static func verifyScreenGeometry() {
        let screens = [
            EdgeGlowGeometry(size: CGSize(width: 1920, height: 1080), cornerRadius: 0, notch: nil),
            EdgeGlowGeometry(
                size: CGSize(width: 1512, height: 982),
                cornerRadius: 16,
                notch: CGRect(x: 666, y: 950, width: 180, height: 32)
            ),
            EdgeGlowGeometry(size: CGSize(width: 3008, height: 1692), cornerRadius: 0, notch: nil)
        ]
        for geometry in screens {
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let bounds = CGRect(origin: .zero, size: geometry.size)
            precondition(geometry.contour.contains(center))
            for depth: CGFloat in [44, 72] {
                for scale: CGFloat in [1, 2] {
                    let strips = geometry.strips(depth: depth, scale: scale)
                    // The compositor has no image pixels in the center and
                    // adjacent textures never overlap to create bright seams.
                    for (index, strip) in strips.enumerated() {
                        precondition(!strip.contains(center))
                        precondition(bounds.contains(strip))
                        for other in strips.dropFirst(index + 1) {
                            let intersection = strip.intersection(other)
                            precondition(intersection.isNull || intersection.width * intersection.height == 0)
                        }
                    }
                    for point in [
                        CGPoint(x: 1, y: center.y),
                        CGPoint(x: geometry.size.width - 1, y: center.y),
                        CGPoint(x: center.x, y: 1),
                        CGPoint(x: 100, y: geometry.size.height - 1)
                    ] {
                        precondition(strips.contains { $0.contains(point) })
                    }
                }
            }
            if let notch = geometry.notch {
                precondition(!geometry.contour.contains(CGPoint(x: notch.midX, y: notch.midY)))
                precondition(geometry.contour.contains(CGPoint(x: notch.midX, y: notch.minY - 1)))
                precondition(geometry.contour.contains(CGPoint(x: notch.minX - 10, y: notch.midY)))
                precondition(geometry.contour.contains(CGPoint(x: notch.maxX + 10, y: notch.midY)))
            }
            if geometry.cornerRadius > 0 {
                precondition(!geometry.contour.contains(CGPoint(x: 1, y: 1)))
                precondition(!geometry.contour.contains(CGPoint(x: 1, y: geometry.size.height - 1)))
            }
        }
    }
}
