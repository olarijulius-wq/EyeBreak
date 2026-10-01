import SwiftUI

enum Theme: String, CaseIterable {
    case graphite
    case sage
    case peach
    case lavender
    case ocean
    case midnight
    case ember
    case matcha
    case frost
    case dusk
    case mono

    var displayName: String {
        rawValue.capitalized
    }

    // Raw identifiers and automatic time bands are persistence contracts.
    // Palettes reinterpret those choices without changing their stored values.
    var atmosphere: AtmospherePalette {
        let colors: [UInt32]
        switch self {
        case .graphite: colors = [0x8D7461, 0x514442, 0x766A4D]
        case .sage: colors = [0x79815A, 0x3F5744, 0x8C693D]
        case .peach: colors = [0xC68B65, 0x8C4736, 0x9E7843]
        case .lavender: colors = [0x887089, 0x563E64, 0x9A694E]
        case .ocean: colors = [0x527E82, 0x244653, 0x82704C]
        case .midnight: colors = [0x4D526E, 0x302C4C, 0x706048]
        case .ember: return .ember
        case .matcha: colors = [0x92925C, 0x4E603D, 0x9A7644]
        case .frost: colors = [0x809493, 0x4C6270, 0x9A8164]
        case .dusk: colors = [0xA16A70, 0x60394F, 0xAA7846]
        case .mono: colors = [0x716960, 0x403B39, 0x59544C]
        }
        return AtmospherePalette(
            base: EyeBreakDesign.base,
            colors: colors.map { Color(hex: $0) }
        )
    }

    func atmosphere(isNightMode: Bool) -> AtmospherePalette {
        isNightMode ? atmosphere.dimmed() : atmosphere
    }

    static func automatic(forHour hour: Int) -> Theme {
        switch hour {
        case 5..<9:
            return .frost
        case 9..<12:
            return .matcha
        case 12..<16:
            return .sage
        case 16..<19:
            return .peach
        case 19..<22:
            return .dusk
        default:
            return .midnight
        }
    }
}
