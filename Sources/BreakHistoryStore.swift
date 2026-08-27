import Combine
import Foundation

struct BreakDayRecord: Codable, Equatable {
    var completed: Int
    var skipped: Int

    static let empty = BreakDayRecord(completed: 0, skipped: 0)
}

struct BreakHistoryDay: Identifiable, Equatable {
    let date: Date
    let dateKey: String
    let completed: Int
    let skipped: Int

    var id: String { dateKey }
    var total: Int { completed + skipped }
}

final class BreakHistoryStore: ObservableObject {
    static let defaultsKey = "breakHistory"

    @Published private(set) var records: [String: BreakDayRecord]

    private let userDefaults: UserDefaults
    private let fixedTimeZone: TimeZone?

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = fixedTimeZone ?? .autoupdatingCurrent
        return calendar
    }

    init(
        userDefaults: UserDefaults = .standard,
        calendar sourceCalendar: Calendar? = nil
    ) {
        self.userDefaults = userDefaults
        fixedTimeZone = sourceCalendar?.timeZone

        if
            let data = userDefaults.data(forKey: Self.defaultsKey),
            let decoded = try? JSONDecoder().decode(
                [String: BreakDayRecord].self,
                from: data
            )
        {
            records = decoded.mapValues { record in
                BreakDayRecord(
                    completed: max(0, record.completed),
                    skipped: max(0, record.skipped)
                )
            }
        } else {
            records = [:]
        }

        pruneOlderThan30Days()
    }

    func recordCompletedBreak(at date: Date = Date()) {
        updateRecord(at: date) { record in
            record.completed += 1
        }
    }

    func recordSkippedBreak(at date: Date = Date()) {
        updateRecord(at: date) { record in
            record.skipped += 1
        }
    }

    func todayCompletedCount(at date: Date = Date()) -> Int {
        records[dateKey(for: date)]?.completed ?? 0
    }

    func currentStreak(endingAt date: Date = Date()) -> Int {
        var day = calendar.startOfDay(for: date)
        var streak = 0

        while (records[dateKey(for: day)]?.completed ?? 0) > 0 {
            streak += 1

            guard let previousDay = calendar.date(
                byAdding: .day,
                value: -1,
                to: day
            ) else {
                break
            }

            day = previousDay
        }

        return streak
    }

    func lastSevenDays(endingAt date: Date = Date()) -> [BreakHistoryDay] {
        let today = calendar.startOfDay(for: date)

        return (-6...0).compactMap { offset in
            guard
                let day = calendar.date(
                    byAdding: .day,
                    value: offset,
                    to: today
                )
            else {
                return nil
            }

            let key = dateKey(for: day)
            let record = records[key] ?? .empty
            return BreakHistoryDay(
                date: day,
                dateKey: key,
                completed: record.completed,
                skipped: record.skipped
            )
        }
    }

    func pruneOlderThan30Days(referenceDate: Date = Date()) {
        let today = calendar.startOfDay(for: referenceDate)
        guard
            let cutoff = calendar.date(
                byAdding: .day,
                value: -29,
                to: today
            )
        else {
            return
        }

        let pruned = records.filter { key, _ in
            guard let day = date(fromKey: key) else {
                return false
            }
            return day >= cutoff && day <= today
        }

        guard pruned != records else {
            return
        }

        records = pruned
        persist()
    }

    func refreshForCurrentDay(at date: Date = Date()) {
        pruneOlderThan30Days(referenceDate: date)
        objectWillChange.send()
    }

    private func updateRecord(
        at date: Date,
        update: (inout BreakDayRecord) -> Void
    ) {
        let key = dateKey(for: date)
        var record = records[key] ?? .empty
        update(&record)
        records[key] = record
        pruneOlderThan30Days(referenceDate: date)
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        guard let data = try? encoder.encode(records) else {
            return
        }

        userDefaults.set(data, forKey: Self.defaultsKey)
    }

    private func dateKey(for date: Date) -> String {
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

    private func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            return nil
        }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day

        guard let date = calendar.date(from: components) else {
            return nil
        }

        return dateKey(for: date) == key ? date : nil
    }
}
