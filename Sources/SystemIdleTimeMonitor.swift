import CoreGraphics
import Foundation

protocol SystemIdleTimeSource {
    func secondsSinceLastSystemInput() -> TimeInterval?
}

protocol SystemIdleTimeMonitoring: AnyObject {
    func idleTime() -> TimeInterval?
    func hasReachedResetThreshold(_ threshold: TimeInterval) -> Bool
}

/// Reads macOS-wide keyboard and mouse idle time. This is deliberately kept
/// separate from the scheduler so its source can be replaced in tests.
struct CoreGraphicsSystemIdleTimeSource: SystemIdleTimeSource {
    func secondsSinceLastSystemInput() -> TimeInterval? {
        CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .init(rawValue: ~0)!
        )
    }
}

final class SystemIdleTimeMonitor: SystemIdleTimeMonitoring {
    // Anything beyond a year is almost certainly a malformed API result. It
    // also makes a bad value fall back to normal scheduling instead of causing
    // an unexpected reset.
    private static let maximumPlausibleIdleTime: TimeInterval = 365 * 24 * 60 * 60

    private let source: SystemIdleTimeSource
    private let logger: (String) -> Void
    private var hasLoggedUnavailableValue = false

    init(
        source: SystemIdleTimeSource = CoreGraphicsSystemIdleTimeSource(),
        logger: @escaping (String) -> Void = { message in
            NSLog("%@", message)
        }
    ) {
        self.source = source
        self.logger = logger
    }

    func idleTime() -> TimeInterval? {
        guard let idleTime = source.secondsSinceLastSystemInput(),
              idleTime.isFinite,
              idleTime >= 0,
              idleTime <= Self.maximumPlausibleIdleTime
        else {
            logUnavailableValueOnce()
            return nil
        }

        return idleTime
    }

    func hasReachedResetThreshold(_ threshold: TimeInterval) -> Bool {
        guard threshold > 0, let idleTime = idleTime() else {
            return false
        }

        return idleTime >= threshold
    }

    private func logUnavailableValueOnce() {
        guard !hasLoggedUnavailableValue else {
            return
        }

        hasLoggedUnavailableValue = true
        logger("EyeBreak could not read a valid system idle time; continuing without idle resets.")
    }
}

enum SystemIdleTime {
    static let shared: SystemIdleTimeMonitoring = SystemIdleTimeMonitor()
}
