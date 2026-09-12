import AppKit
import Foundation

private final class MockIdleTimeSource: SystemIdleTimeSource {
    private var values: [TimeInterval?]
    private(set) var callCount = 0

    init(_ values: [TimeInterval?]) {
        self.values = values
    }

    func secondsSinceLastSystemInput() -> TimeInterval? {
        callCount += 1
        return values.isEmpty ? nil : values.removeFirst()
    }
}

@main
struct SystemIdleTimeMonitorTests {
    static func main() {
        testThresholdResetsToAFullWorkInterval()
        testOffDoesNotReadOrResetForIdleTime()
        testInvalidIdleTimeLogsOnceAndFallsBack()
        print("SystemIdleTimeMonitorTests passed")
    }

    private static func testThresholdResetsToAFullWorkInterval() {
        let source = MockIdleTimeSource([10 * 60])
        let monitor = SystemIdleTimeMonitor(source: source, logger: { _ in })
        let defaults = makeDefaults()
        defaults.set(15, forKey: BreakScheduler.breakIntervalDefaultsKey)
        defaults.set(10, forKey: BreakScheduler.resetTimerAfterAwayDefaultsKey)
        let scheduler = makeScheduler(defaults: defaults, monitor: monitor)
        let resetDate = Date(timeIntervalSinceReferenceDate: 1_000_000)

        scheduler.pollSystemIdleTime(at: resetDate)

        guard let nextFireDate = scheduler.nextFireDate else {
            fail("Expected an idle threshold to schedule a new work interval.")
        }
        expect(
            abs(nextFireDate.timeIntervalSince(resetDate) - 15 * 60) < 0.01,
            "Expected a full interval after returning from an away break."
        )
        scheduler.stop()
    }

    private static func testOffDoesNotReadOrResetForIdleTime() {
        let source = MockIdleTimeSource([60 * 60])
        let monitor = SystemIdleTimeMonitor(source: source, logger: { _ in })
        let defaults = makeDefaults()
        defaults.set(0, forKey: BreakScheduler.resetTimerAfterAwayDefaultsKey)
        let scheduler = makeScheduler(defaults: defaults, monitor: monitor)

        scheduler.pollSystemIdleTime(at: Date(timeIntervalSinceReferenceDate: 1_000_000))

        expect(source.callCount == 0, "Expected the Off setting not to query idle time.")
        expect(scheduler.nextFireDate == nil, "Expected the Off setting not to reset the timer.")
        scheduler.stop()
    }

    private static func testInvalidIdleTimeLogsOnceAndFallsBack() {
        let source = MockIdleTimeSource([.nan, -1])
        var logCount = 0
        let monitor = SystemIdleTimeMonitor(source: source, logger: { _ in
            logCount += 1
        })

        expect(
            !monitor.hasReachedResetThreshold(10 * 60),
            "Expected invalid idle time not to reset the timer."
        )
        expect(
            !monitor.hasReachedResetThreshold(10 * 60),
            "Expected a second invalid idle time not to reset the timer."
        )
        expect(logCount == 1, "Expected invalid idle time to be logged only once.")
    }

    private static func makeDefaults() -> UserDefaults {
        guard let defaults = UserDefaults(
            suiteName: "SystemIdleTimeMonitorTests.\(UUID().uuidString)"
        ) else {
            fatalError("Could not create test defaults.")
        }
        return defaults
    }

    private static func makeScheduler(
        defaults: UserDefaults,
        monitor: SystemIdleTimeMonitoring
    ) -> BreakScheduler {
        BreakScheduler(
            userDefaults: defaults,
            onPreWarning: {},
            onBreak: {},
            systemIdleMonitor: monitor
        )
    }

    private static func expect(_ condition: Bool, _ message: String) {
        guard condition else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fatalError("Test failure: \(message)")
    }
}
