import AppKit
import SwiftUI

final class StatsPanelController: NSWindowController {
    static let contentSize = NSSize(width: 400, height: 260)

    private let historyStore: BreakHistoryStore

    init(historyStore: BreakHistoryStore) {
        self.historyStore = historyStore

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Break Stats"
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.contentViewController = NSHostingController(
            rootView: BreakStatsView(historyStore: historyStore)
        )

        super.init(window: panel)
        shouldCascadeWindows = false

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarContextChanged(_:)),
            name: .NSCalendarDayChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarContextChanged(_:)),
            name: .NSSystemTimeZoneDidChange,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show() {
        guard let window else {
            return
        }

        historyStore.refreshForCurrentDay()

        if !window.isVisible {
            window.center()
        }

        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func calendarContextChanged(_ notification: Notification) {
        historyStore.refreshForCurrentDay()
    }
}

private struct BreakStatsView: View {
    @ObservedObject var historyStore: BreakHistoryStore

    var body: some View {
        let days = historyStore.lastSevenDays()

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(historyStore.todayCompletedCount())")
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())

                Text("completed today")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                LegendItem(color: .accentColor, title: "Completed")
                LegendItem(color: .secondary.opacity(0.55), title: "Skipped")
            }

            WeeklyBreakBarChart(days: days)
                .frame(height: 116)
        }
        .padding(20)
        .frame(
            minWidth: StatsPanelController.contentSize.width,
            minHeight: StatsPanelController.contentSize.height,
            alignment: .topLeading
        )
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct LegendItem: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WeeklyBreakBarChart: View {
    let days: [BreakHistoryDay]

    private var maximumTotal: Int {
        max(1, days.map(\.total).max() ?? 0)
    }

    var body: some View {
        GeometryReader { geometry in
            let barAreaHeight = max(1, geometry.size.height - 22)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(days) { day in
                    VStack(spacing: 5) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.10))

                            VStack(spacing: 1) {
                                if day.completed > 0 {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.accentColor)
                                        .frame(
                                            height: segmentHeight(
                                                day.completed,
                                                availableHeight: barAreaHeight
                                            )
                                        )
                                }

                                if day.skipped > 0 {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.secondary.opacity(0.55))
                                        .frame(
                                            height: segmentHeight(
                                                day.skipped,
                                                availableHeight: barAreaHeight
                                            )
                                        )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: barAreaHeight)
                        .help(
                            "\(day.completed) completed, \(day.skipped) skipped"
                        )

                        Text(day.date, format: .dateTime.weekday(.narrow))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        Text(day.date, format: .dateTime.weekday(.wide))
                    )
                    .accessibilityValue(
                        "\(day.completed) completed, \(day.skipped) skipped"
                    )
                }
            }
        }
    }

    private func segmentHeight(
        _ count: Int,
        availableHeight: CGFloat
    ) -> CGFloat {
        availableHeight * CGFloat(count) / CGFloat(maximumTotal)
    }
}
