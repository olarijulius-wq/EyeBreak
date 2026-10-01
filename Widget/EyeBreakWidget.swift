import Darwin
import Foundation
import SwiftUI
import WidgetKit

private struct WidgetSummary: Decodable {
    let schemaVersion: Int
    let completedByDate: [String: Int]
}

private enum WidgetSummaryReader {
    static func completedByDate() -> [String: Int] {
        guard
            let summaryURL = summaryURL(),
            let data = try? Data(contentsOf: summaryURL),
            let summary = try? JSONDecoder().decode(WidgetSummary.self, from: data),
            summary.schemaVersion == 1
        else {
            return [:]
        }

        return summary.completedByDate.mapValues { max(0, $0) }
    }

    private static func summaryURL() -> URL? {
        guard
            let account = getpwuid(getuid()),
            let physicalHome = account.pointee.pw_dir
        else {
            return nil
        }

        return URL(
            fileURLWithPath: String(cString: physicalHome),
            isDirectory: true
        )
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("Application Support", isDirectory: true)
        .appendingPathComponent("EyeBreak", isDirectory: true)
        .appendingPathComponent("widget-summary.json", isDirectory: false)
    }
}

private struct DailyBreakStat: Identifiable {
    let date: Date
    let dateKey: String
    let completed: Int

    var id: String { dateKey }
}

private struct EyeBreakEntry: TimelineEntry {
    let date: Date
    let todayCompleted: Int
    let currentStreak: Int
    let lastSevenDays: [DailyBreakStat]
}

private struct EyeBreakTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> EyeBreakEntry {
        makeEntry(at: Date(), completedByDate: [:])
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (EyeBreakEntry) -> Void
    ) {
        completion(makeEntry(at: Date()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<EyeBreakEntry>) -> Void
    ) {
        let now = Date()
        let entry = makeEntry(at: now)
        let nextRefresh = now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry(at date: Date) -> EyeBreakEntry {
        makeEntry(
            at: date,
            completedByDate: WidgetSummaryReader.completedByDate()
        )
    }

    private func makeEntry(
        at date: Date,
        completedByDate: [String: Int]
    ) -> EyeBreakEntry {
        let calendar = statisticsCalendar()
        let today = calendar.startOfDay(for: date)
        let todayKey = dateKey(for: today, calendar: calendar)
        let lastSevenDays: [DailyBreakStat] = (-6...0).compactMap { offset in
            guard
                let day = calendar.date(
                    byAdding: .day,
                    value: offset,
                    to: today
                )
            else {
                return nil
            }

            let key = dateKey(for: day, calendar: calendar)
            return DailyBreakStat(
                date: day,
                dateKey: key,
                completed: completedByDate[key] ?? 0
            )
        }

        return EyeBreakEntry(
            date: date,
            todayCompleted: completedByDate[todayKey] ?? 0,
            currentStreak: currentStreak(
                endingAt: today,
                completedByDate: completedByDate,
                calendar: calendar
            ),
            lastSevenDays: lastSevenDays
        )
    }

    private func currentStreak(
        endingAt today: Date,
        completedByDate: [String: Int],
        calendar: Calendar
    ) -> Int {
        var day = today
        var streak = 0

        while completedByDate[dateKey(for: day, calendar: calendar), default: 0] > 0 {
            streak += 1

            guard
                let previousDay = calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: day
                )
            else {
                break
            }

            day = previousDay
        }

        return streak
    }

    private func statisticsCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    private func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )

        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

private struct EyeBreakWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: EyeBreakEntry

    var body: some View {
        Group {
            if family == .systemMedium {
                mediumContent
            } else {
                smallContent
            }
        }
        .foregroundStyle(EyeBreakDesign.textPrimary)
        .preferredColorScheme(.dark)
        .containerBackground(for: .widget) {
            AtmosphereBackground(palette: .ember, animated: false)
        }
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            MicroLabel("TODAY")

            Spacer(minLength: EyeBreakDesign.Spacing.xxs)

            completedCount(size: 56)

            Text("Completed breaks")
                .font(EyeBreakDesign.Typography.metadata)
                .foregroundStyle(EyeBreakDesign.textSecondary)

            Spacer(minLength: EyeBreakDesign.Spacing.xs)

            streakLabel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumContent: some View {
        HStack(spacing: EyeBreakDesign.Spacing.lg) {
            VStack(alignment: .leading, spacing: 0) {
                MicroLabel("TODAY")

                Spacer(minLength: EyeBreakDesign.Spacing.xxs)

                completedCount(size: 56)

                Text("Completed breaks")
                    .font(EyeBreakDesign.Typography.metadata)
                    .foregroundStyle(EyeBreakDesign.textSecondary)

                Spacer(minLength: EyeBreakDesign.Spacing.xs)
                streakLabel
            }
            .frame(width: 108, alignment: .leading)

            VStack(alignment: .leading, spacing: EyeBreakDesign.Spacing.sm) {
                MicroLabel("LAST 7 DAYS")

                WeeklyBreakBars(days: entry.lastSevenDays)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func completedCount(size: CGFloat) -> some View {
        Text("\(entry.todayCompleted)")
            .font(.system(size: size, weight: .light))
            .tracking(-1.8)
            .monospacedDigit()
            .minimumScaleFactor(0.65)
            .lineLimit(1)
            .accessibilityLabel("\(entry.todayCompleted) completed breaks today")
    }

    private var streakLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: EyeBreakDesign.Spacing.xs) {
            MicroLabel("STREAK")
            Text("\(entry.currentStreak) \(entry.currentStreak == 1 ? "day" : "days")")
                .font(EyeBreakDesign.Typography.metadata)
                .foregroundStyle(EyeBreakDesign.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current streak, \(entry.currentStreak) days")
    }
}

private struct WeeklyBreakBars: View {
    let days: [DailyBreakStat]

    private var maximumCompleted: Int {
        max(1, days.map(\.completed).max() ?? 0)
    }

    var body: some View {
        DayStrip(
            labels: days.map { $0.date.formatted(.dateTime.weekday(.narrow)) },
            selectedIndex: days.indices.last,
            values: days.map { Double($0.completed) / Double(maximumCompleted) },
            accessibilityLabels: days.map { day in
                let date = day.date.formatted(date: .abbreviated, time: .omitted)
                return "\(date), \(day.completed) completed breaks"
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Completed breaks in the last seven days")
    }
}

@main
struct EyeBreakWidget: Widget {
    private let kind = "com.olari.EyeBreak.stats"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: EyeBreakTimelineProvider()
        ) { entry in
            EyeBreakWidgetView(entry: entry)
        }
        .configurationDisplayName("EyeBreak Stats")
        .description("See today's completed breaks and your current streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
