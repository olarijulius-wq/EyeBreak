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
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = NSColor(EyeBreakDesign.base)

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
            animate: window.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
    }
}

private struct BreakStatsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var historyStore: BreakHistoryStore
    let onDetailExpansionChanged: (Bool) -> Void

    @State private var selectedDayKey: String?

    var body: some View {
        let days = historyStore.lastSevenDays()

        VStack(alignment: .leading, spacing: EyeBreakDesign.Spacing.sm) {
            HStack(alignment: .center, spacing: EyeBreakDesign.Spacing.md) {
                Text("\(historyStore.todayCompletedCount())")
                    .font(.system(size: 64, weight: .light))
                    .tracking(-2)
                    .monospacedDigit()
                    .foregroundStyle(EyeBreakDesign.textPrimary)
                    .contentTransition(.numericText())

                VStack(alignment: .leading, spacing: EyeBreakDesign.Spacing.xxs) {
                    MicroLabel("TODAY")
                    Text("Completed breaks")
                        .font(EyeBreakDesign.Typography.metadata)
                        .foregroundStyle(EyeBreakDesign.textSecondary)
                }
            }
            .frame(height: 76)

            HStack(spacing: EyeBreakDesign.Spacing.md) {
                LegendItem(color: EyeBreakDesign.textPrimary, title: "Completed")
                LegendItem(color: EyeBreakDesign.textSecondary, title: "Skipped")
                LegendItem(color: EyeBreakDesign.rust, title: "Held")
            }

            WeeklyBreakBarChart(
                days: days,
                selectedDayKey: selectedDayKey,
                onSelect: selectDay
            )
                .frame(height: 100)

            if
                let selectedDayKey,
                let selectedDay = days.first(where: {
                    $0.dateKey == selectedDayKey
                })
            {
                DayBreakTimeline(day: selectedDay)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, EyeBreakDesign.Spacing.sm)
                    .transition(.opacity)
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
        .background(AtmosphereBackground(palette: .ember))
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: reduceMotion ? 0.1 : 0.25), value: selectedDayKey)
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
        HStack(spacing: EyeBreakDesign.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)

            Text(title)
                .font(EyeBreakDesign.Typography.metadata)
                .foregroundStyle(EyeBreakDesign.textSecondary)
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
            let barAreaHeight = max(1, geometry.size.height - 38)

            VStack(spacing: EyeBreakDesign.Spacing.xs) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(days) { day in
                        Button {
                            onSelect(day.dateKey)
                        } label: {
                            ZStack(alignment: .bottom) {
                                Capsule()
                                    .fill(EyeBreakDesign.textTertiary.opacity(0.2))
                                    .frame(width: 2)

                                if day.heldSeconds > 0 {
                                    Capsule()
                                        .fill(EyeBreakDesign.rust.opacity(0.75))
                                        .frame(
                                            width: 12,
                                            height: heldHeight(
                                                day.heldSeconds,
                                                availableHeight: barAreaHeight
                                            )
                                        )
                                }

                                VStack(spacing: 1) {
                                    if day.completed > 0 {
                                        Capsule()
                                            .fill(EyeBreakDesign.textPrimary)
                                            .frame(
                                                width: 4,
                                                height: segmentHeight(
                                                    day.completed,
                                                    availableHeight: barAreaHeight
                                                )
                                            )
                                    }

                                    if day.skipped > 0 {
                                        Capsule()
                                            .fill(EyeBreakDesign.textSecondary)
                                            .frame(
                                                width: 4,
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
                            .background(GlowSelection(isActive: day.dateKey == selectedDayKey))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .help(daySummary(day))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            Text(day.date, format: .dateTime.weekday(.wide))
                        )
                        .accessibilityValue(daySummary(day))
                    }
                }

                DayStrip(
                    labels: days.map { $0.date.formatted(.dateTime.weekday(.narrow)) },
                    selectedIndex: days.firstIndex { $0.dateKey == selectedDayKey }
                        ?? days.indices.last,
                    onSelect: { index in onSelect(days[index].dateKey) },
                    accessibilityLabels: days.map { day in
                        day.date.formatted(date: .complete, time: .omitted)
                            + ", " + daySummary(day)
                    }
                )
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

    var body: some View {
        VStack(alignment: .leading, spacing: EyeBreakDesign.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(
                    day.date,
                    format: .dateTime
                        .weekday(.wide)
                        .month(.abbreviated)
                        .day()
                )
                .font(EyeBreakDesign.Typography.metadata)
                .foregroundStyle(EyeBreakDesign.textPrimary)

                Spacer()

                Text(breakCountDescription)
                    .font(EyeBreakDesign.Typography.metadata)
                    .foregroundStyle(EyeBreakDesign.textSecondary)
            }

            if day.entries.isEmpty {
                Text("No timestamp details were recorded for this day.")
                    .font(EyeBreakDesign.Typography.metadata)
                    .foregroundStyle(EyeBreakDesign.textSecondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: EyeBreakDesign.Spacing.sm) {
                        ForEach(Array(day.entries.enumerated()), id: \.offset) { _, entry in
                            HStack(spacing: EyeBreakDesign.Spacing.sm) {
                                Text(entry.time, format: .dateTime.hour().minute())
                                    .monospacedDigit()
                                    .foregroundStyle(EyeBreakDesign.textSecondary)
                                    .frame(width: 72, alignment: .leading)

                                Circle()
                                    .fill(color(for: entry.outcome))
                                    .frame(width: 4, height: 4)

                                Text(entry.outcome == .completed ? "Completed" : "Skipped")
                                    .foregroundStyle(color(for: entry.outcome))

                                Spacer(minLength: 0)
                            }
                            .font(EyeBreakDesign.Typography.metadata)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(entryDescription(entry))
                        }
                    }
                    .padding(.vertical, EyeBreakDesign.Spacing.xxs)
                }
                .scrollIndicators(.hidden)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Break timeline"))
    }

    private var breakCountDescription: String {
        let count = day.total
        return "\(count) \(count == 1 ? "break" : "breaks")"
    }

    private func color(for outcome: BreakOutcome) -> Color {
        switch outcome {
        case .completed:
            return EyeBreakDesign.textPrimary
        case .skipped:
            return EyeBreakDesign.textSecondary
        }
    }

    private func entryDescription(_ entry: BreakHistoryEntry) -> String {
        let outcome = entry.outcome == .completed ? "Completed" : "Skipped"
        let time = entry.time.formatted(date: .omitted, time: .shortened)
        return "\(outcome) at \(time)"
    }
}
