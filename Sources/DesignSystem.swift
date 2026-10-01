import SwiftUI

// Shared by the app and widget extension. Keep this file free of app state.
enum EyeBreakDesign {
    static let base = Color(hex: 0x050303)
    static let textPrimary = Color(hex: 0xF2EEE9)
    static let textSecondary = Color.white.opacity(0.55)
    // Decorative marks only. Small, meaningful text uses textSecondary for AA.
    static let textTertiary = Color.white.opacity(0.35)
    static let glow = Color.white
    static let amber = Color(hex: 0xD9AA72)
    static let rust = Color(hex: 0xA85D44)

    enum Typography {
        static let display = Font.system(size: 40, weight: .light)
        static let metadata = Font.system(size: 12, weight: .regular)
        static let micro = Font.system(size: 10, weight: .regular)
        static let displayTracking: CGFloat = -1.2
        static let metadataTracking: CGFloat = 0
        static let microTracking: CGFloat = 1.8
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let card: CGFloat = 28
        static let control: CGFloat = 12
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: 1
        )
    }
}

struct AtmospherePalette {
    let base: Color
    let colors: [Color]
    var intensity: Double = 0.80
    var driftDuration: Double = 32

    static let ember = AtmospherePalette(
        base: EyeBreakDesign.base,
        colors: [Color(hex: 0xC67A3E), Color(hex: 0x7A2E1C), Color(hex: 0x7D6A35)]
    )

    func dimmed() -> Self {
        Self(base: .black, colors: colors, intensity: intensity * 0.48, driftDuration: 40)
    }
}

struct AtmosphereBackground: View {
    let palette: AtmospherePalette
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            palette.base
            if animated && !reduceMotion {
                // Three soft radial fields, sampled at 12fps. No per-blob blur
                // surfaces or full-rate animation; widgets take the static path.
                TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
                    fields(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                fields(at: 0)
            }
            // A permanent scrim keeps small secondary text above 4.5:1 even
            // where fields overlap; atmosphere dissolves into black below.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.52), location: 0),
                    .init(color: .black.opacity(0.58), location: 0.30),
                    .init(color: .black.opacity(0.88), location: 0.72),
                    .init(color: .black, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .environment(\.colorScheme, .dark)
    }

    private func fields(at time: TimeInterval) -> some View {
        Canvas { context, size in
            let phase = time / max(20, palette.driftDuration) * 2 * Double.pi
            let anchors: [CGPoint] = [
                CGPoint(x: 0.15, y: 0.08),
                CGPoint(x: 0.78, y: 0.18),
                CGPoint(x: 0.48, y: -0.12),
                CGPoint(x: 0.92, y: 0.02)
            ]
            for (index, color) in palette.colors.prefix(4).enumerated() {
                let anchor = anchors[index]
                let offset = Double(index) * 2.1
                let center = CGPoint(
                    x: size.width * (anchor.x + CGFloat(sin(phase + offset)) * 0.08),
                    y: size.height * (anchor.y + CGFloat(cos(phase + offset)) * 0.06)
                )
                let radius = max(size.width * (index == 0 ? 0.68 : 0.53), size.height * 0.65)
                let bounds = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.fill(
                    Path(ellipseIn: bounds),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: color.opacity(palette.intensity), location: 0),
                            .init(color: color.opacity(palette.intensity * 0.55), location: 0.28),
                            .init(color: color.opacity(palette.intensity * 0.12), location: 0.65),
                            .init(color: color.opacity(0), location: 1)
                        ]),
                        center: center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
    }
}

struct GlowRing<Content: View>: View {
    var progress: Double?
    var diameter: CGFloat
    var lineWidth: CGFloat
    private let content: Content

    init(progress: Double? = nil, diameter: CGFloat = 56, lineWidth: CGFloat = 1.5, @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.diameter = diameter
        self.lineWidth = lineWidth
        self.content = content()
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(EyeBreakDesign.glow.opacity(0.22), lineWidth: lineWidth * 3)
                .blur(radius: 5)
            Circle()
                .stroke(EyeBreakDesign.glow.opacity(progress == nil ? 0.85 : 0.22), lineWidth: lineWidth)
            if let progress {
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(EyeBreakDesign.glow.opacity(0.95), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            content
                .foregroundStyle(EyeBreakDesign.textPrimary)
        }
        .frame(width: diameter, height: diameter)
    }
}

struct GlowSelection: View {
    let isActive: Bool

    var body: some View {
        RadialGradient(
            colors: [EyeBreakDesign.glow.opacity(0.12), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 36
        )
        // Fixed field reaches transparent at its edges even behind a tiny tab.
        // As a background it can overflow the label without changing hit areas.
        .frame(width: 72, height: 72)
        .opacity(isActive ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct MicroLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(EyeBreakDesign.Typography.micro)
            .tracking(EyeBreakDesign.Typography.microTracking)
            .foregroundStyle(EyeBreakDesign.textSecondary)
    }
}

struct DayStrip: View {
    let labels: [String]
    var selectedIndex: Int?
    var values: [Double] = []
    var onSelect: ((Int) -> Void)?
    var accessibilityLabels: [String] = []

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(labels.indices, id: \.self) { index in
                if let onSelect {
                    Button { onSelect(index) } label: { day(at: index) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityLabel(at: index))
                        .accessibilityAddTraits(selectedIndex == index ? .isSelected : [])
                } else {
                    day(at: index)
                        .accessibilityLabel(accessibilityLabel(at: index))
                }
            }
        }
    }

    private func accessibilityLabel(at index: Int) -> String {
        accessibilityLabels.indices.contains(index) ? accessibilityLabels[index] : labels[index]
    }

    private func day(at index: Int) -> some View {
        VStack(spacing: 8) {
            if values.indices.contains(index) {
                Capsule()
                    .fill(selectedIndex == index ? EyeBreakDesign.amber : EyeBreakDesign.textTertiary)
                    .frame(width: 3, height: max(2, 36 * min(max(values[index], 0), 1)))
                    .frame(height: 36, alignment: .bottom)
            }
            Text(labels[index])
                .font(EyeBreakDesign.Typography.micro)
                .foregroundStyle(selectedIndex == index ? EyeBreakDesign.textPrimary : EyeBreakDesign.textSecondary)
            Rectangle()
                .fill(selectedIndex == index ? EyeBreakDesign.textPrimary : .clear)
                .frame(width: 12, height: 1)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(GlowSelection(isActive: selectedIndex == index))
        .contentShape(Rectangle())
    }
}
