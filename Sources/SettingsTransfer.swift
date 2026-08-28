import Foundation

struct ImportedSettings {
    let breakIntervalMinutes: Int?
    let adaptiveTimingEnabled: Bool?
    let snoozeUntil: Date?
    let requireStillnessEnabled: Bool?
    let cameraAttentionEnabled: Bool?
    let selectedTheme: String?
    let nightModeEnabled: Bool?
    let focusExerciseEnabled: Bool?
    let soundEnabled: Bool?
    let silentModeEnabled: Bool?
    let dimScreenEnabled: Bool?
    let calendarAwareEnabled: Bool?
    let escapeShortcutEnabled: Bool?
}

enum SettingsTransfer {
    static let currentSchemaVersion = 1
    static let defaultFileName = "eyebreak-settings.json"

    static func export(
        to url: URL,
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main
    ) throws {
        let interval = defaults.integer(
            forKey: BreakScheduler.breakIntervalDefaultsKey
        )
        // breakHistory and breakCount both record completed-break activity,
        // so neither belongs in a settings archive.
        let payload = SettingsPayload(
            breakIntervalMinutes: BreakScheduler.supportedIntervalMinutes
                .contains(interval)
                ? interval
                : BreakScheduler.defaultIntervalMinutes,
            adaptiveTimingEnabled: boolValue(
                forKey: BreakScheduler.adaptiveTimingDefaultsKey,
                defaultValue: false,
                defaults: defaults
            ),
            snoozeUntil: defaults.object(
                forKey: BreakScheduler.snoozeUntilDefaultsKey
            ) as? Date,
            requireStillnessEnabled: boolValue(
                forKey: AppDelegate.requireStillnessEnabledDefaultsKey,
                defaultValue: false,
                defaults: defaults
            ),
            cameraAttentionEnabled: boolValue(
                forKey: AppDelegate.cameraAttentionEnabledDefaultsKey,
                defaultValue: false,
                defaults: defaults
            ),
            selectedTheme: ThemeSelection.normalizedRawValue(
                defaults.string(forKey: AppDelegate.selectedThemeDefaultsKey)
            ),
            nightModeEnabled: boolValue(
                forKey: AppDelegate.nightModeEnabledDefaultsKey,
                defaultValue: true,
                defaults: defaults
            ),
            focusExerciseEnabled: boolValue(
                forKey: AppDelegate.focusExerciseEnabledDefaultsKey,
                defaultValue: true,
                defaults: defaults
            ),
            soundEnabled: boolValue(
                forKey: AppDelegate.soundEnabledDefaultsKey,
                defaultValue: true,
                defaults: defaults
            ),
            silentModeEnabled: boolValue(
                forKey: AppDelegate.silentModeEnabledDefaultsKey,
                defaultValue: false,
                defaults: defaults
            ),
            dimScreenEnabled: boolValue(
                forKey: AppDelegate.dimScreenEnabledDefaultsKey,
                defaultValue: false,
                defaults: defaults
            ),
            calendarAwareEnabled: boolValue(
                forKey: AppDelegate.calendarAwareEnabledDefaultsKey,
                defaultValue: false,
                defaults: defaults
            ),
            escapeShortcutEnabled: boolValue(
                forKey: AppDelegate.escapeShortcutEnabledDefaultsKey,
                defaultValue: false,
                defaults: defaults
            )
        )
        let archive = SettingsArchive(
            schemaVersion: currentSchemaVersion,
            appVersion: bundle.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown",
            settings: payload
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(archive)
            try data.write(to: url, options: .atomic)
        } catch let error as SettingsTransferError {
            throw error
        } catch {
            throw SettingsTransferError.writeFailed(error.localizedDescription)
        }
    }

    static func `import`(from url: URL) throws -> ImportedSettings {
        let data: Data

        do {
            data = try Data(contentsOf: url)
        } catch {
            throw SettingsTransferError.readFailed(error.localizedDescription)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let header: SettingsArchiveHeader

        do {
            header = try decoder.decode(SettingsArchiveHeader.self, from: data)
        } catch {
            throw SettingsTransferError.invalidFile(decodingMessage(for: error))
        }

        guard header.schemaVersion <= currentSchemaVersion else {
            throw SettingsTransferError.newerSchema(
                fileVersion: header.schemaVersion,
                supportedVersion: currentSchemaVersion
            )
        }

        guard header.schemaVersion == currentSchemaVersion else {
            throw SettingsTransferError.unsupportedSchema(header.schemaVersion)
        }

        let archive: SettingsArchive

        do {
            archive = try decoder.decode(SettingsArchive.self, from: data)
        } catch {
            throw SettingsTransferError.invalidFile(decodingMessage(for: error))
        }

        if let interval = archive.settings.breakIntervalMinutes,
           !BreakScheduler.supportedIntervalMinutes.contains(interval) {
            let supportedValues = BreakScheduler.supportedIntervalMinutes
                .map(String.init)
                .joined(separator: ", ")
            throw SettingsTransferError.invalidSetting(
                key: BreakScheduler.breakIntervalDefaultsKey,
                reason: "Use one of: \(supportedValues)."
            )
        }

        if let theme = archive.settings.selectedTheme,
           theme != ThemeSelection.autoRawValue,
           Theme(rawValue: theme) == nil {
            throw SettingsTransferError.invalidSetting(
                key: AppDelegate.selectedThemeDefaultsKey,
                reason: "The theme name is not recognised by this version of EyeBreak."
            )
        }

        return ImportedSettings(
            breakIntervalMinutes: archive.settings.breakIntervalMinutes,
            adaptiveTimingEnabled: archive.settings.adaptiveTimingEnabled,
            snoozeUntil: archive.settings.snoozeUntil,
            requireStillnessEnabled: archive.settings.requireStillnessEnabled,
            cameraAttentionEnabled: archive.settings.cameraAttentionEnabled,
            selectedTheme: archive.settings.selectedTheme,
            nightModeEnabled: archive.settings.nightModeEnabled,
            focusExerciseEnabled: archive.settings.focusExerciseEnabled,
            soundEnabled: archive.settings.soundEnabled,
            silentModeEnabled: archive.settings.silentModeEnabled,
            dimScreenEnabled: archive.settings.dimScreenEnabled,
            calendarAwareEnabled: archive.settings.calendarAwareEnabled,
            escapeShortcutEnabled: archive.settings.escapeShortcutEnabled
        )
    }

    private static func boolValue(
        forKey key: String,
        defaultValue: Bool,
        defaults: UserDefaults
    ) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    private static func decodingMessage(for error: Error) -> String {
        switch error {
        case DecodingError.keyNotFound(let key, let context):
            return "The required \(fieldName(context.codingPath + [key])) field is missing."

        case DecodingError.typeMismatch(_, let context):
            return "The \(fieldName(context.codingPath)) field has the wrong value type."

        case DecodingError.valueNotFound(_, let context):
            return "The \(fieldName(context.codingPath)) field has no value."

        case DecodingError.dataCorrupted(let context):
            return context.debugDescription

        default:
            return error.localizedDescription
        }
    }

    private static func fieldName(_ codingPath: [CodingKey]) -> String {
        let path = codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? "settings file" : "“\(path)”"
    }
}

private struct SettingsArchiveHeader: Decodable {
    let schemaVersion: Int
}

private struct SettingsArchive: Codable {
    let schemaVersion: Int
    let appVersion: String
    let settings: SettingsPayload
}

private struct SettingsPayload: Codable {
    let breakIntervalMinutes: Int?
    let adaptiveTimingEnabled: Bool?
    let snoozeUntil: Date?
    let requireStillnessEnabled: Bool?
    let cameraAttentionEnabled: Bool?
    let selectedTheme: String?
    let nightModeEnabled: Bool?
    let focusExerciseEnabled: Bool?
    let soundEnabled: Bool?
    let silentModeEnabled: Bool?
    let dimScreenEnabled: Bool?
    let calendarAwareEnabled: Bool?
    let escapeShortcutEnabled: Bool?
}

private enum SettingsTransferError: LocalizedError {
    case readFailed(String)
    case writeFailed(String)
    case invalidFile(String)
    case newerSchema(fileVersion: Int, supportedVersion: Int)
    case unsupportedSchema(Int)
    case invalidSetting(key: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .readFailed(let detail):
            return "EyeBreak could not read the selected file. \(detail)"

        case .writeFailed(let detail):
            return "EyeBreak could not write the settings file. \(detail)"

        case .invalidFile(let detail):
            return "The selected file is not a valid EyeBreak settings file. \(detail)"

        case .newerSchema(let fileVersion, let supportedVersion):
            return "This file uses settings schema version \(fileVersion), but this version of EyeBreak only understands up to version \(supportedVersion)."

        case .unsupportedSchema(let version):
            return "Settings schema version \(version) is not supported."

        case .invalidSetting(let key, let reason):
            return "The value for “\(key)” is invalid. \(reason)"
        }
    }
}
