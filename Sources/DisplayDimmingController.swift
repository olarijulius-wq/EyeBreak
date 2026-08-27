import CoreGraphics
import Darwin
import Foundation

final class DisplayDimmingController {
    private typealias GetBrightness = @convention(c) (
        CGDirectDisplayID,
        UnsafeMutablePointer<Float>
    ) -> CInt
    private typealias SetBrightness = @convention(c) (
        CGDirectDisplayID,
        Float
    ) -> CInt

    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
    private static let dimmedBrightness: Float = 0.4
    private static let fadeDuration: TimeInterval = 1.5
    private static let fadeStepCount = 30

    private let frameworkHandle: UnsafeMutableRawPointer?
    private let getBrightness: GetBrightness?
    private let setBrightness: SetBrightness?

    private var activeDisplayID: CGDirectDisplayID?
    private var originalBrightness: Float?
    private var fadeTimer: Timer?
    private var fadeGeneration = 0

    init() {
        guard let handle = dlopen(Self.frameworkPath, RTLD_LAZY) else {
            frameworkHandle = nil
            getBrightness = nil
            setBrightness = nil
            return
        }

        guard
            let getSymbol = dlsym(handle, "DisplayServicesGetBrightness"),
            let setSymbol = dlsym(handle, "DisplayServicesSetBrightness")
        else {
            _ = dlclose(handle)
            frameworkHandle = nil
            getBrightness = nil
            setBrightness = nil
            return
        }

        frameworkHandle = handle
        getBrightness = unsafeBitCast(getSymbol, to: GetBrightness.self)
        setBrightness = unsafeBitCast(setSymbol, to: SetBrightness.self)
    }

    deinit {
        restore(immediately: true)

        if let frameworkHandle {
            _ = dlclose(frameworkHandle)
        }
    }

    func dim(displayID: CGDirectDisplayID) {
        guard let getBrightness, setBrightness != nil else {
            return
        }

        if let activeDisplayID, activeDisplayID != displayID {
            restore(immediately: true)
        }

        var currentBrightness: Float = 0
        guard getBrightness(displayID, &currentBrightness) == 0 else {
            return
        }

        if originalBrightness == nil {
            activeDisplayID = displayID
            originalBrightness = currentBrightness
        }

        fade(
            displayID: displayID,
            from: currentBrightness,
            to: Self.dimmedBrightness
        )
    }

    func restore(immediately: Bool = false) {
        guard
            let displayID = activeDisplayID,
            let originalBrightness,
            let getBrightness,
            let setBrightness
        else {
            stopFade()
            clearActiveDisplay()
            return
        }

        stopFade()

        if immediately {
            _ = setBrightness(displayID, originalBrightness)
            clearActiveDisplay()
            return
        }

        var currentBrightness: Float = 0
        guard getBrightness(displayID, &currentBrightness) == 0 else {
            _ = setBrightness(displayID, originalBrightness)
            clearActiveDisplay()
            return
        }

        fade(
            displayID: displayID,
            from: currentBrightness,
            to: originalBrightness
        ) { [weak self] in
            guard self?.activeDisplayID == displayID else {
                return
            }

            self?.clearActiveDisplay()
        }
    }

    private func fade(
        displayID: CGDirectDisplayID,
        from startBrightness: Float,
        to targetBrightness: Float,
        completion: (() -> Void)? = nil
    ) {
        guard let setBrightness else {
            return
        }

        stopFade()

        if abs(startBrightness - targetBrightness) < 0.001 {
            _ = setBrightness(displayID, targetBrightness)
            completion?()
            return
        }

        let generation = fadeGeneration
        var step = 0
        let interval = Self.fadeDuration / Double(Self.fadeStepCount)
        let timer = Timer(timeInterval: interval, repeats: true) {
            [weak self] timer in
            guard let self, generation == self.fadeGeneration else {
                timer.invalidate()
                return
            }

            step += 1
            let progress = min(
                1,
                Float(step) / Float(Self.fadeStepCount)
            )
            let brightness = startBrightness
                + ((targetBrightness - startBrightness) * progress)
            _ = setBrightness(displayID, brightness)

            if step >= Self.fadeStepCount {
                timer.invalidate()
                self.fadeTimer = nil
                completion?()
            }
        }

        fadeTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopFade() {
        fadeGeneration &+= 1
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    private func clearActiveDisplay() {
        activeDisplayID = nil
        originalBrightness = nil
    }
}
