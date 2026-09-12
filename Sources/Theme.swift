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

    var background: LinearGradient {
        gradient(startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    func gradient(
        startPoint: UnitPoint,
        endPoint: UnitPoint
    ) -> LinearGradient {
        let colors: [Color]

        switch self {
        case .graphite:
            colors = [
                Color(red: 0.20, green: 0.22, blue: 0.25),
                Color(red: 0.07, green: 0.08, blue: 0.10)
            ]
        case .sage:
            colors = [
                Color(red: 0.32, green: 0.47, blue: 0.35),
                Color(red: 0.13, green: 0.27, blue: 0.19)
            ]
        case .peach:
            colors = [
                Color(red: 1.00, green: 0.75, blue: 0.64),
                Color(red: 0.88, green: 0.43, blue: 0.39)
            ]
        case .lavender:
            colors = [
                Color(red: 0.43, green: 0.34, blue: 0.66),
                Color(red: 0.24, green: 0.17, blue: 0.43)
            ]
        case .ocean:
            colors = [
                Color(red: 0.08, green: 0.43, blue: 0.57),
                Color(red: 0.04, green: 0.28, blue: 0.49)
            ]
        case .midnight:
            colors = [
                Color(red: 0.10, green: 0.12, blue: 0.32),
                Color(red: 0.02, green: 0.02, blue: 0.07)
            ]
        case .ember:
            colors = [
                Color(red: 0.16, green: 0.15, blue: 0.15),
                Color(red: 0.34, green: 0.05, blue: 0.06)
            ]
        case .matcha:
            colors = [
                Color(red: 0.96, green: 0.93, blue: 0.78),
                Color(red: 0.57, green: 0.68, blue: 0.49)
            ]
        case .frost:
            colors = [
                Color(red: 0.78, green: 0.92, blue: 1.00),
                Color(red: 0.98, green: 1.00, blue: 1.00)
            ]
        case .dusk:
            colors = [
                Color(red: 0.54, green: 0.31, blue: 0.42),
                Color(red: 0.20, green: 0.10, blue: 0.31)
            ]
        case .mono:
            colors = [.black, .black]
        }

        return LinearGradient(
            colors: colors,
            startPoint: startPoint,
            endPoint: endPoint
        )
    }

    var accent: Color {
        accent(saturationScale: 1)
    }

    func accent(saturationScale: Double) -> Color {
        let components = accentComponents

        return Color(
            hue: components.hue,
            saturation: components.saturation
                * min(max(saturationScale, 0), 1),
            brightness: components.brightness
        )
    }

    func countdownAccent(progress: Double) -> Color {
        let progress = min(max(progress, 0), 1)
        let components = accentComponents
        let saturationScale = 0.35 + (0.65 * progress)

        return Color(
            hue: components.hue,
            saturation: components.saturation * saturationScale,
            brightness: components.brightness
        )
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

    private var accentComponents: (
        hue: Double,
        saturation: Double,
        brightness: Double
    ) {
        switch self {
        case .graphite:
            return (hue: 0.540, saturation: 0.510, brightness: 0.980)
        case .sage:
            return (hue: 0.124, saturation: 0.561, brightness: 0.980)
        case .peach:
            return (hue: 0.976, saturation: 0.756, brightness: 0.450)
        case .lavender:
            return (hue: 0.112, saturation: 0.550, brightness: 1.000)
        case .ocean:
            return (hue: 0.471, saturation: 0.421, brightness: 0.950)
        case .midnight:
            return (hue: 0.529, saturation: 0.680, brightness: 1.000)
        case .ember:
            return (hue: 0.064, saturation: 0.780, brightness: 1.000)
        case .matcha:
            return (hue: 0.370, saturation: 0.600, brightness: 0.300)
        case .frost:
            return (hue: 0.597, saturation: 0.862, brightness: 0.580)
        case .dusk:
            return (hue: 0.114, saturation: 0.454, brightness: 0.970)
        case .mono:
            return (hue: 0, saturation: 0, brightness: 1)
        }
    }

    var foreground: Color {
        switch self {
        case .peach:
            return Color(red: 0.20, green: 0.09, blue: 0.08)
        case .matcha:
            return Color(red: 0.08, green: 0.18, blue: 0.11)
        case .frost:
            return Color(red: 0.06, green: 0.15, blue: 0.25)
        case .graphite, .sage, .lavender, .ocean, .midnight, .ember, .dusk, .mono:
            return .white
        }
    }
}
