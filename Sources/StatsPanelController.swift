import AppKit
import SwiftUI

final class StatsPanelController: NSWindowController {
    static let contentSize = NSSize(width: 400, height: 260)
    static let expandedContentSize = NSSize(width: 400, height: 420)

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

        super.init(window: panel)
        shouldCascadeWindows = false

        panel.contentViewController = NSHostingController(
            rootView: BreakStatsView(
                historyStore: historyStore,
                onDetailExpansionChanged: { [weak self] isExpanded in
                    self?.setDetailExpanded(isExpanded)
                }
            )
        )

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

    private func setDetailExpanded(_ isExpanded: Bool) {
        guard let window else {
            return
        }

        let contentSize = isExpanded
            ? Self.expandedContentSize
            : Self.contentSize
        let currentFrame = window.frame
        var targetFrame = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: contentSize)
        )
        targetFrame.origin = NSPoint(
            x: currentFrame.minX,
            y: currentFrame.maxY - targetFrame.height
        )

        guard targetFrame != currentFrame else {
            return
        }

        window.setFrame(
            targetFrame,
            display: true,
            animate: window.isVisible
        )
    }
}

private struct BreakStatsView: View {
    @ObservedObject var historyStore: BreakHistoryStore
    let onDetailExpansionChanged: (Bool) -> Void

    @State private var selectedDayKey: String?

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
                LegendItem(color: .accentColor.opacity(0.22), title: "Held")
            }

            WeeklyBreakBarChart(
                days: days,
                selectedDayKey: selectedDayKey,
                onSelect: selectDay
            )
                .frame(height: 116)

            if
                let selectedDayKey,
                let selectedDay = days.first(where: {
                    $0.dateKey == selectedDayKey
                })
            {
                DayBreakTimeline(day: selectedDay)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .frame(
            width: StatsPanelController.contentSize.width,
            height: selectedDayKey == nil
                ? StatsPanelController.contentSize.height
                : StatsPanelController.expandedContentSize.height,
            alignment: .topLeading
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.18), value: selectedDayKey)
        .onChange(of: selectedDayKey) { _, newValue in
            onDetailExpansionChanged(newValue != nil)
        }
        .onChange(of: days.map(\.dateKey)) { _, dateKeys in
            guard
                let selectedDayKey,
                !dateKeys.contains(selectedDayKey)
            else {
                return
            }

            self.selectedDayKey = nil
        }
    }

    private func selectDay(_ dateKey: String) {
        selectedDayKey = selectedDayKey == dateKey ? nil : dateKey
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
    let selectedDayKey: String?
    let onSelect: (String) -> Void

    private var maximumTotal: Int {
        max(1, days.map(\.total).max() ?? 0)
    }

    private var maximumHeldSeconds: TimeInterval {
        max(1, days.map(\.heldSeconds).max() ?? 0)
    }

    var body: some View {
        GeometryReader { geometry in
            let barAreaHeight = max(1, geometry.size.height - 22)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(days) { day in
                    Button {
                        onSelect(day.dateKey)
                    } label: {
                        VStack(spacing: 5) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.10))

                                if day.heldSeconds > 0 {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.accentColor.opacity(0.22))
                                        .frame(
                                            height: heldHeight(
                                                day.heldSeconds,
                                                availableHeight: barAreaHeight
                                            )
                                        )
                                        .padding(.horizontal, 2)
                                }

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
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 6)

                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(
                                        day.dateKey == selectedDayKey
                                            ? Color.accentColor
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: barAreaHeight)

                            Text(day.date, format: .dateTime.weekday(.narrow))
                                .font(.caption2)
                                .foregroundStyle(
                                    day.dateKey == selectedDayKey
                                        ? Color.accentColor
                                        : Color.secondary
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .help(daySummary(day))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        Text(day.date, format: .dateTime.weekday(.wide))
                    )
                    .accessibilityValue(daySummary(day))
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

    private func heldHeight(
        _ seconds: TimeInterval,
        availableHeight: CGFloat
    ) -> CGFloat {
        availableHeight * CGFloat(seconds / maximumHeldSeconds)
    }

    private func daySummary(_ day: BreakHistoryDay) -> String {
        "\(day.completed) completed, \(day.skipped) skipped, "
            + "\(durationDescription(day.heldSeconds)) held"
    }

    private func durationDescription(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else {
            return "0 seconds"
        }

        let roundedSeconds = seconds.rounded()
        guard roundedSeconds < TimeInterval(Int.max) else {
            return "a very long time"
        }

        let totalSeconds = max(0, Int(roundedSeconds))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60

        if minutes > 0 {
            let minuteUnit = minutes == 1 ? "minute" : "minutes"
            guard remainingSeconds > 0 else {
                return "\(minutes) \(minuteUnit)"
            }

            let secondUnit = remainingSeconds == 1 ? "second" : "seconds"
            return "\(minutes) \(minuteUnit) \(remainingSeconds) \(secondUnit)"
        }

        let secondUnit = totalSeconds == 1 ? "second" : "seconds"
        return "\(totalSeconds) \(secondUnit)"
    }
}

private struct DayBreakTimeline: View {
    let day: BreakHistoryDay

    private let timelineHours = [6, 9, 12, 15, 18, 21, 24]
    private let horizontalInset: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(
                    day.date,
                    format: .dateTime
                        .weekday(.wide)
                        .month(.abbreviated)
                        .day()
                )
                .font(.subheadline.weight(.semibold))

                Spacer()

                Text(breakCountDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                let lineY: CGFloat = 16

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.28))
                        .frame(
                            width: max(
                                0,
                                geometry.size.width - (horizontalInset * 2)
                            ),
                            height: 1
                        )
                        .position(x: geometry.size.width / 2, y: lineY)

                    ForEach(timelineHours, id: \.self) { hour in
                        let x = position(
                            forHour: Double(hour),
                            width: geometry.size.width
                        )

                        Rectangle()
                            .fill(Color.secondary.opacity(0.32))
                            .frame(width: 1, height: 9)
                            .position(x: x, y: lineY)

                        Text(String(format: "%02d:00", hour))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .position(x: x, y: 40)
                    }

                    ForEach(
                        Array(day.entries.enumerated()),
                        id: \.offset
                    ) { _, entry in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(color(for: entry.outcome))
                            .frame(width: 3, height: 23)
                            .position(
                                x: position(
                                    for: entry.time,
                                    width: geometry.size.width
                                ),
                                y: lineY
                            )
                            .help(entryDescription(entry))
                            .accessibilityLabel(entryDescription(entry))
                    }
                }
            }
            .frame(height: 52)

            if day.entries.isEmpty {
                Text("No timestamp details were recorded for this day.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.07))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            Text("Break timeline from 6 AM to midnight")
        )
    }

    private var breakCountDescription: String {
        let count = day.total
        return "\(count) \(count == 1 ? "break" : "breaks")"
    }

    private func position(for date: Date, width: CGFloat) -> CGFloat {
        let components = Calendar.autoupdatingCurrent.dateComponents(
            [.hour, .minute, .second],
            from: date
        )
        let hour = Double(components.hour ?? 0)
            + (Double(components.minute ?? 0) / 60)
            + (Double(components.second ?? 0) / 3_600)

        return position(forHour: hour, width: width)
    }

    private func position(forHour hour: Double, width: CGFloat) -> CGFloat {
        let clampedHour = min(max(hour, 6), 24)
        let availableWidth = max(0, width - (horizontalInset * 2))
        let progress = CGFloat((clampedHour - 6) / 18)
        return horizontalInset + (availableWidth * progress)
    }

    private func color(for outcome: BreakOutcome) -> Color {
        switch outcome {
        case .completed:
            return .accentColor
        case .skipped:
            return .secondary.opacity(0.65)
        }
    }

    private func entryDescription(_ entry: BreakHistoryEntry) -> String {
        let outcome = entry.outcome == .completed ? "Completed" : "Skipped"
        let time = entry.time.formatted(date: .omitted, time: .shortened)
        return "\(outcome) at \(time)"
    }
}
