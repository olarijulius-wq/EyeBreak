import Foundation

private struct WidgetSummary: Encodable {
    let schemaVersion: Int
    let completedByDate: [String: Int]
}

enum WidgetSummaryWriter {
    private static let schemaVersion = 1
    private static let directoryName = "EyeBreak"
    private static let fileName = "widget-summary.json"

    static func write(records: [String: BreakDayRecord]) {
        guard let directoryURL = summaryDirectoryURL() else {
            return
        }

        let summary = WidgetSummary(
            schemaVersion: schemaVersion,
            completedByDate: records.mapValues { record in
                max(0, record.completed)
            }
        )

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(summary)
            try data.write(
                to: directoryURL.appendingPathComponent(fileName),
                options: .atomic
            )
        } catch {
            // Widget data is a best-effort mirror and must not affect history.
        }
    }

    private static func summaryDirectoryURL() -> URL? {
        let accountName = NSUserName()
        guard
            !accountName.isEmpty,
            let homePath = NSHomeDirectoryForUser(accountName),
            !homePath.isEmpty
        else {
            return nil
        }

        return URL(fileURLWithPath: homePath, isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }
}
