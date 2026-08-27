import AppKit
import CoreGraphics

struct PresentationGuard {
    private static let fullScreenTolerance: CGFloat = 2

    static func shouldSuppressBreak() -> Bool {
        if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
           hasFullScreenWindow(
               processIdentifier: frontmostApplication.processIdentifier
           ) {
            return true
        }

        return hasActiveScreenCaptureSession()
    }

    static func secondsSinceLastInput() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .init(rawValue: ~0)!
        )
    }

    private static func hasFullScreenWindow(processIdentifier: pid_t) -> Bool {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        let screenFrames = NSScreen.screens.compactMap { screen -> CGRect? in
            guard let screenNumber = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber else {
                return nil
            }

            return CGDisplayBounds(CGDirectDisplayID(screenNumber.uint32Value))
        }

        return windowInfo.contains { window in
            guard
                let layer = window[kCGWindowLayer as String] as? NSNumber,
                layer.intValue == 0,
                let ownerPID = window[kCGWindowOwnerPID as String] as? NSNumber,
                ownerPID.int32Value == processIdentifier,
                let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
            else {
                return false
            }

            return screenFrames.contains { screenFrame in
                boundsMatch(bounds, screenFrame: screenFrame)
            }
        }
    }

    private static func hasActiveScreenCaptureSession() -> Bool {
        // Without capture access, window names may be unavailable. Fail open
        // instead of guessing that a sharing session is active.
        guard CGPreflightScreenCaptureAccess() else {
            return false
        }

        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier

        return windowInfo.contains { window in
            guard
                let layer = window[kCGWindowLayer as String] as? NSNumber,
                layer.intValue > 0,
                let ownerPID = window[kCGWindowOwnerPID as String] as? NSNumber,
                ownerPID.int32Value != currentProcessIdentifier,
                let windowName = window[kCGWindowName as String] as? String
            else {
                return false
            }

            return windowName.contains("Screen Sharing")
                || windowName.contains("is sharing your screen")
        }
    }

    private static func boundsMatch(_ bounds: CGRect, screenFrame: CGRect) -> Bool {
        abs(bounds.origin.x - screenFrame.origin.x) <= fullScreenTolerance
            && abs(bounds.origin.y - screenFrame.origin.y) <= fullScreenTolerance
            && abs(bounds.size.width - screenFrame.size.width) <= fullScreenTolerance
            && abs(bounds.size.height - screenFrame.size.height) <= fullScreenTolerance
    }
}
