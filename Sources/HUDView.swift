import AppKit
import Combine
import Foundation
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

enum CardShape: CaseIterable {
    case capsule
    case squircle
    case pill
    case blob
    case tag
    case leaf

    var shape: AnyShape {
        switch self {
        case .capsule:
            return AnyShape(Capsule(style: .continuous))
        case .squircle:
            return AnyShape(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
            )
        case .pill:
            return AnyShape(HalfHeightRoundedRectangle())
        case .blob:
            return AnyShape(
                AsymmetricRoundedForm(
                    topLeftRadius: 44,
                    topRightRadius: 18,
                    bottomRightRadius: 38,
                    bottomLeftRadius: 24
                )
            )
        case .tag:
            return AnyShape(
                AsymmetricRoundedForm(
                    topLeftRadius: 30,
                    topRightRadius: 30,
                    bottomRightRadius: 30,
                    bottomLeftRadius: 0
                )
            )
        case .leaf:
            return AnyShape(LeafShape())
        }
    }
}

enum EntranceStyle: CaseIterable {
    case bubble
    case unfurl
    case swing
    case pour
    case pop
    case slide

    var duration: TimeInterval {
        switch self {
        case .bubble:
            return 0.64
        case .unfurl:
            return 0.70
        case .swing:
            return 0.65
        case .pour:
            return 0.68
        case .pop:
            return 0.35
        case .slide:
            return 0.54
        }
    }

    var restingOffsetY: CGFloat {
        8
    }
}

enum ExitStyle: CaseIterable {
    case shrinkToNotch
    case fall
    case dissolve

    var duration: TimeInterval {
        switch self {
        case .shrinkToNotch:
            return 0.28
        case .fall:
            return 0.50
        case .dissolve:
            return 0.42
        }
    }
}

enum CardSizeVariant: Equatable {
    case standard
    case wide
    case compact
}

private struct HalfHeightRoundedRectangle: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(
            cornerRadius: rect.height / 2,
            style: .circular
        )
        .path(in: rect)
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        let fullRadius = min(rect.width, rect.height)

        return AsymmetricRoundedForm(
            topLeftRadius: 0,
            topRightRadius: fullRadius,
            bottomRightRadius: 0,
            bottomLeftRadius: fullRadius
        )
        .path(in: rect)
    }
}

private struct AsymmetricRoundedForm: Shape {
    let topLeftRadius: CGFloat
    let topRightRadius: CGFloat
    let bottomRightRadius: CGFloat
    let bottomLeftRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radii = fittedRadii(in: rect)
        var path = Path()

        path.move(
            to: CGPoint(x: rect.minX + radii.topLeft, y: rect.minY)
        )
        path.addLine(
            to: CGPoint(x: rect.maxX - radii.topRight, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radii.topRight),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(
            to: CGPoint(x: rect.maxX, y: rect.maxY - radii.bottomRight)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radii.bottomRight, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(
            to: CGPoint(x: rect.minX + radii.bottomLeft, y: rect.maxY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radii.bottomLeft),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(
            to: CGPoint(x: rect.minX, y: rect.minY + radii.topLeft)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radii.topLeft, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()

        return path
    }

    private func fittedRadii(in rect: CGRect) -> (
        topLeft: CGFloat,
        topRight: CGFloat,
        bottomRight: CGFloat,
        bottomLeft: CGFloat
    ) {
        let topLeft = max(0, topLeftRadius)
        let topRight = max(0, topRightRadius)
        let bottomRight = max(0, bottomRightRadius)
        let bottomLeft = max(0, bottomLeftRadius)
        let largestHorizontalPair = max(
            topLeft + topRight,
            bottomLeft + bottomRight
        )
        let largestVerticalPair = max(
            topLeft + bottomLeft,
            topRight + bottomRight
        )
        let horizontalScale = largestHorizontalPair > 0
            ? rect.width / largestHorizontalPair
            : 1
        let verticalScale = largestVerticalPair > 0
            ? rect.height / largestVerticalPair
            : 1
        let scale = min(1, horizontalScale, verticalScale)

        return (
            topLeft: topLeft * scale,
            topRight: topRight * scale,
            bottomRight: bottomRight * scale,
            bottomLeft: bottomLeft * scale
        )
    }
}

enum HUDLayout {
    // The transparent margin keeps the blurred glow visible through the
    // widest card's entrance stretch and a full 120-point downward drag.
    static let panelSize = CGSize(width: 780, height: 344)
    static let minimumCardWidth: CGFloat = 320
    static let maximumCardWidth: CGFloat = 560
    static let standardCardHeight: CGFloat = 96
    static let wideCardHeight: CGFloat = 64
    static let compactCardHeight: CGFloat = 110
    static let longBreakCardHeight: CGFloat = 130
    static let notchedCardTopPadding: CGFloat = 32
    static let noNotchCardTopInset: CGFloat = 12
    static let eyeWidth: CGFloat = 34
    static let standardContentSpacing: CGFloat = 14
    static let standardSpacerMinimumWidth: CGFloat = 8
    static let standardHorizontalContentPadding: CGFloat = 22
    static let standardCountdownDiameter: CGFloat = 48
    static let cardSizeVariantWidthAdjustment: CGFloat = 140
}

enum FocusExercisePhase: CaseIterable, Equatable {
    case initialFar
    case near
    case finalFar

    var subtitle: String {
        switch self {
        case .initialFar:
            return "Look at something far away"
        case .near:
            return "Now look at your fingertip, arm's length"
        case .finalFar:
            return "Back to something far away"
        }
    }

    var accentSaturationScale: Double {
        self == .near ? 0.6 : 1
    }
}

final class HUDViewState: ObservableObject {
    static let regularDuration: TimeInterval = 20
    static let longBreakDuration: TimeInterval = 120
    static let heldSubtitle = "Hands off — the timer is waiting"
    static let messages: [(title: String, subtitle: String)] = [
        ("Take an eye break", "Look 20 feet away for 20 seconds"),
        ("Look away", "Find something far outside the window"),
        ("Blink reset", "Blink slowly twenty times"),
        ("Unclench", "Drop your shoulders, straighten your back"),
        ("Distance check", "Focus on the furthest thing you can see"),
        ("Breathe", "Four in, four out, eyes closed"),
        ("Stretch", "Roll your neck once each way")
    ]
    static let morningMessages: [(title: String, subtitle: String)] = [
        ("Ease in", "Let your eyes settle on something far away"),
        ("Slow start", "Blink softly and look beyond the screen"),
        ("Morning reset", "Find the daylight and relax your focus"),
        ("Wake gently", "Look across the room for twenty seconds"),
        ("Fresh eyes", "Drop your shoulders and soften your gaze")
    ]
    static let eveningMessages: [(title: String, subtitle: String)] = [
        ("Winding down", "Let your eyes rest beyond the screen"),
        ("Last stretch", "Look far away and loosen your shoulders"),
        ("Evening reset", "Blink slowly and soften your focus"),
        ("Almost done", "Give your eyes twenty quiet seconds"),
        ("Clocking off", "Look away and breathe out slowly")
    ]
    static let deepWorkMessages: [(title: String, subtitle: String)] = [
        ("Screen break", "Lift your focus beyond the display"),
        ("Deep work reset", "Release your focus from the screen"),
        ("Refocus", "Look past the pixels for twenty seconds"),
        ("Focus buffer", "Give your eyes a different distance"),
        ("Step out of the code", "Find the furthest point you can see")
    ]
    static let longBreakMessages: [(title: String, subtitle: String)] = [
        ("Long break", "Stand up and walk away for two minutes"),
        ("Move", "Get water, stretch, look out a window"),
        ("Step away", "Two minutes off the screen")
    ]

    private static let deepWorkBundleIdentifierFragments = [
        "xcode",
        "terminal",
        "iterm",
        "code",
        "ghostty"
    ]

    let duration: TimeInterval
    let isLongBreak: Bool
    let message: (title: String, subtitle: String)
    let completedBreaksInCycle: Int
    let currentStreak: Int
    let isNightMode: Bool
    let isSilentMode: Bool
    let isInformational: Bool
    let screenHasNotch: Bool
    let cardShape: CardShape
    let entranceStyle: EntranceStyle
    let exitStyle: ExitStyle
    let cardSizeVariant: CardSizeVariant
    let isSlowMotionEntrance: Bool
    private let standardNaturalCardWidth: CGFloat
    private let focusExerciseNaturalCardWidth: CGFloat
    private(set) var entranceStartedAt: Date?
    @Published var remainingSeconds: TimeInterval
    @Published var isDismissing = false
    @Published var isPaused = false
    @Published var isHeld = false
    @Published var theme: Theme
    @Published var focusExerciseEnabled: Bool
    @Published private(set) var blinkTrigger = 0

    let blinkTimer = Timer.publish(
        every: 4,
        on: .main,
        in: .common
    ).autoconnect()

    init(
        theme: Theme,
        duration: TimeInterval,
        focusExerciseEnabled: Bool,
        completedBreakCount: Int,
        currentStreak: Int,
        isNightMode: Bool,
        isSilentMode: Bool,
        screenHasNotch: Bool,
        date: Date,
        calendar: Calendar,
        frontmostApplicationBundleIdentifier: String?,
        messageOverride: (title: String, subtitle: String)? = nil,
        isInformational: Bool = false
    ) {
        self.duration = duration
        self.isInformational = isInformational
        isLongBreak = !isInformational
            && duration == Self.longBreakDuration

        let selectedMessage: (title: String, subtitle: String)

        if let messageOverride {
            selectedMessage = messageOverride
        } else {
            let messagePool = Self.messagePool(
                isLongBreak: isLongBreak,
                date: date,
                calendar: calendar,
                frontmostApplicationBundleIdentifier: frontmostApplicationBundleIdentifier
            )
            selectedMessage = messagePool.randomElement() ?? messagePool[0]
        }

        message = selectedMessage
        standardNaturalCardWidth = Self.naturalCardWidth(
            for: selectedMessage
        )
        focusExerciseNaturalCardWidth = Self.naturalCardWidth(
            for: selectedMessage,
            additionalSubtitles: FocusExercisePhase.allCases.map {
                $0.subtitle
            }
        )
        completedBreaksInCycle = max(0, completedBreakCount) % 4
        self.currentStreak = max(0, currentStreak)
        self.isNightMode = isNightMode
        self.isSilentMode = isSilentMode
        self.screenHasNotch = screenHasNotch
        cardShape = CardShape.allCases.randomElement() ?? .squircle
        let entranceStyles = screenHasNotch
            ? EntranceStyle.allCases
            : EntranceStyle.allCases.filter { style in
                switch style {
                case .bubble, .unfurl:
                    return false
                case .swing, .pour, .pop, .slide:
                    return true
                }
            }
        entranceStyle = entranceStyles.randomElement() ?? .slide
        exitStyle = ExitStyle.allCases.randomElement() ?? .shrinkToNotch

        if Int.random(in: 0..<15) == 0 {
            cardSizeVariant = Bool.random() ? .wide : .compact
        } else {
            cardSizeVariant = .standard
        }

        isSlowMotionEntrance = Int.random(in: 0..<25) == 0
        remainingSeconds = duration
        self.theme = theme
        self.focusExerciseEnabled = focusExerciseEnabled
    }

    private static func messagePool(
        isLongBreak: Bool,
        date: Date,
        calendar: Calendar,
        frontmostApplicationBundleIdentifier: String?
    ) -> [(title: String, subtitle: String)] {
        if isLongBreak {
            return longBreakMessages
        }

        let hour = calendar.component(.hour, from: date)

        if hour < 9 {
            return morningMessages
        }

        if hour >= 21 {
            return eveningMessages
        }

        let bundleIdentifier = frontmostApplicationBundleIdentifier?.lowercased() ?? ""
        let isDeepWorkApp = deepWorkBundleIdentifierFragments.contains { fragment in
            bundleIdentifier.contains(fragment)
        }

        return isDeepWorkApp ? deepWorkMessages : messages
    }

    private static func naturalCardWidth(
        for message: (title: String, subtitle: String),
        additionalSubtitles: [String] = []
    ) -> CGFloat {
        let titleWidth = naturalTextWidth(
            message.title,
            size: 17,
            weight: .semibold
        )
        let subtitleWidth = ([message.subtitle] + additionalSubtitles)
            .map {
                naturalTextWidth(
                    $0,
                    size: 13,
                    weight: .regular
                )
            }
            .max() ?? 0
        let heldSubtitleWidth = naturalTextWidth(
            heldSubtitle,
            size: 13,
            weight: .regular
        )
        let textWidth = max(titleWidth, subtitleWidth, heldSubtitleWidth)
        let hStackSpacing = HUDLayout.standardContentSpacing * 3

        return ceil(
            (HUDLayout.standardHorizontalContentPadding * 2)
                + HUDLayout.eyeWidth
                + textWidth
                + HUDLayout.standardSpacerMinimumWidth
                + HUDLayout.standardCountdownDiameter
                + hStackSpacing
        )
    }

    private static func naturalTextWidth(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight
    ) -> CGFloat {
        let words = text.split(whereSeparator: { $0.isWhitespace })
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        let wordWidth = words.reduce(CGFloat.zero) { total, word in
            total + (String(word) as NSString).size(
                withAttributes: [.font: font]
            ).width
        }
        let interwordSpacing = CGFloat(max(0, words.count - 1)) * size * 0.24
        return wordWidth + interwordSpacing
    }

    var cardHeight: CGFloat {
        switch cardSizeVariant {
        case .wide:
            return HUDLayout.wideCardHeight
        case .compact:
            return HUDLayout.compactCardHeight
        case .standard:
            break
        }

        return isLongBreak
            ? HUDLayout.longBreakCardHeight
            : HUDLayout.standardCardHeight
    }

    var cardSize: CGSize {
        let naturalCardWidth = showsFocusExercise
            ? focusExerciseNaturalCardWidth
            : standardNaturalCardWidth
        let desiredWidth: CGFloat

        switch cardSizeVariant {
        case .standard:
            desiredWidth = naturalCardWidth
        case .wide:
            desiredWidth = naturalCardWidth
                + HUDLayout.cardSizeVariantWidthAdjustment
        case .compact:
            desiredWidth = naturalCardWidth
                - HUDLayout.cardSizeVariantWidthAdjustment
        }

        let width = min(
            max(desiredWidth, HUDLayout.minimumCardWidth),
            HUDLayout.maximumCardWidth
        )
        return CGSize(width: width, height: cardHeight)
    }

    var cardTopPadding: CGFloat {
        if screenHasNotch {
            return HUDLayout.notchedCardTopPadding
        }

        return max(
            0,
            HUDLayout.noNotchCardTopInset - entranceStyle.restingOffsetY
        )
    }

    var restingCardTopInset: CGFloat {
        cardTopPadding + entranceStyle.restingOffsetY
    }

    var entranceDurationMultiplier: Double {
        isSlowMotionEntrance ? 2.5 : 1
    }

    var hasCompletedEntrance: Bool {
        guard let entranceStartedAt else { return false }

        return Date().timeIntervalSince(entranceStartedAt)
            >= entranceStyle.duration * entranceDurationMultiplier
    }

    var progress: Double {
        min(max(remainingSeconds / duration, 0), 1)
    }

    var showsFocusExercise: Bool {
        focusExerciseEnabled
            && !isInformational
            && duration == Self.regularDuration
    }

    var focusExercisePhase: FocusExercisePhase? {
        guard showsFocusExercise else {
            return nil
        }

        let elapsedSeconds = duration - remainingSeconds

        if elapsedSeconds < 10 {
            return .initialFar
        }

        if elapsedSeconds < 15 {
            return .near
        }

        return .finalFar
    }

    var displayedSubtitle: String {
        if isHeld {
            return Self.heldSubtitle
        }

        return focusExercisePhase?.subtitle ?? message.subtitle
    }

    var countdownAccent: Color {
        guard let focusExercisePhase else {
            return theme.countdownAccent(progress: progress)
        }

        return theme.accent(
            saturationScale: focusExercisePhase.accentSaturationScale
        )
    }

    var displayedSeconds: Int {
        max(0, Int(ceil(remainingSeconds)))
    }

    var displayedTime: String {
        guard isLongBreak else {
            return "\(displayedSeconds)"
        }

        return String(
            format: "%d:%02d",
            displayedSeconds / 60,
            displayedSeconds % 60
        )
    }

    func triggerBlink() {
        blinkTrigger += 1
    }

    func markEntranceStarted() {
        entranceStartedAt = Date()
    }
}

private struct EntranceAnimationValues {
    var scaleX: CGFloat
    var scaleY: CGFloat
    var offsetX: CGFloat
    var offsetY: CGFloat
    var rotation: Double
    var opacity: Double

    static let bubbleInitial = EntranceAnimationValues(
        scaleX: 0.30,
        scaleY: 0.15,
        offsetX: 0,
        offsetY: -20,
        rotation: 0,
        opacity: 0
    )

    static let unfurlInitial = EntranceAnimationValues(
        scaleX: 1,
        scaleY: 0.02,
        offsetX: 0,
        offsetY: -8,
        rotation: 0,
        opacity: 1
    )

    static let swingInitial = EntranceAnimationValues(
        scaleX: 1,
        scaleY: 1,
        offsetX: -40,
        offsetY: 8,
        rotation: -8,
        opacity: 0
    )

    static let pourInitial = EntranceAnimationValues(
        scaleX: 0.20,
        scaleY: 1.20,
        offsetX: 0,
        offsetY: -8,
        rotation: 0,
        opacity: 0.2
    )

    static let popInitial = EntranceAnimationValues(
        scaleX: 0.40,
        scaleY: 0.40,
        offsetX: 0,
        offsetY: 8,
        rotation: 0,
        opacity: 1
    )

    static let slideInitial = EntranceAnimationValues(
        scaleX: 1,
        scaleY: 1,
        offsetX: -300,
        offsetY: 8,
        rotation: -6,
        opacity: 1
    )
}

private struct ExitAnimationValues {
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var offsetY: CGFloat = 0
    var rotation: Double = 0
    var blurRadius: CGFloat = 0
    var opacity: Double = 1
}

struct HUDView: View {
    @ObservedObject var state: HUDViewState
    let onDismiss: () -> Void
    let onHoverChanged: (Bool) -> Void

    @State private var entranceTrigger = 0
    @State private var glowIsPulsing = false
    @State private var fallbackBlinkScaleY: CGFloat = 1
    @State private var dragOffset: CGFloat = 0
    @State private var maximumDragTranslation: CGFloat = 0
    @State private var tiltX = 0.0
    @State private var tiltY = 0.0
    @State private var exitAnimationValues = ExitAnimationValues()

    var body: some View {
        animatedCard
            .onContinuousHover(coordinateSpace: .local) { phase in
                updateTilt(for: phase)
            }
            .scaleEffect(isInFinalThreeSeconds ? 0.97 : 1)
            .rotation3DEffect(
                .degrees(tiltX),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.6
            )
            .rotation3DEffect(
                .degrees(tiltY),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.6
            )
            .animation(
                .easeInOut(duration: 0.4),
                value: isInFinalThreeSeconds
            )
            .offset(y: dragOffset)
            .gesture(cardDragGesture)
            .help(
                state.isInformational
                    ? ""
                    : "Right-click to snooze breaks for 30 minutes"
            )
            .onHover(perform: onHoverChanged)
            .padding(.top, state.cardTopPadding)
            .frame(
                width: HUDLayout.panelSize.width,
                height: HUDLayout.panelSize.height,
                alignment: .top
            )
            .onAppear {
                DispatchQueue.main.async {
                    guard !state.isDismissing else { return }
                    state.markEntranceStarted()
                    entranceTrigger += 1
                    glowIsPulsing = true
                }
            }
            .onReceive(state.blinkTimer) { _ in
                guard !state.isDismissing else { return }
                state.triggerBlink()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(cardAccessibilityLabel)
            .accessibilityHint(
                state.isInformational
                    ? ""
                    : "Right-click to snooze breaks for 30 minutes"
            )
    }

    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                guard
                    !state.isDismissing,
                    !state.isInformational
                else {
                    return
                }
                dragOffset = rubberBandOffset(for: value.translation.height)
                maximumDragTranslation = max(
                    maximumDragTranslation,
                    hypot(value.translation.width, value.translation.height)
                )
            }
            .onEnded { value in
                guard !state.isInformational else {
                    return
                }

                let totalTranslation = max(
                    maximumDragTranslation,
                    hypot(value.translation.width, value.translation.height)
                )
                maximumDragTranslation = 0

                withAnimation(
                    .spring(response: 0.4, dampingFraction: 0.55)
                ) {
                    dragOffset = 0
                }

                if totalTranslation < 4 {
                    onDismiss()
                }
            }
    }

    private func rubberBandOffset(for translation: CGFloat) -> CGFloat {
        if translation >= 0 {
            return min(
                CGFloat(pow(Double(translation), 0.75)),
                120
            )
        }

        return max(translation / 4, -20)
    }

    private func updateTilt(for phase: HoverPhase) {
        switch phase {
        case .active(let location):
            let horizontalPosition = min(
                max((location.x / state.cardSize.width) * 2 - 1, -1),
                1
            )
            let verticalPosition = min(
                max((location.y / cardHeight) * 2 - 1, -1),
                1
            )

            tiltX = -Double(verticalPosition) * 4
            tiltY = Double(horizontalPosition) * 4

        case .ended:
            withAnimation(
                .spring(response: 0.35, dampingFraction: 0.7)
            ) {
                tiltX = 0
                tiltY = 0
            }
        }
    }

    private var animatedCard: some View {
        entranceAnimatedCard
            .scaleEffect(
                x: exitAnimationValues.scaleX,
                y: exitAnimationValues.scaleY,
                anchor: .top
            )
            .rotationEffect(
                .degrees(exitAnimationValues.rotation),
                anchor: .top
            )
            .offset(y: exitAnimationValues.offsetY)
            .blur(radius: exitAnimationValues.blurRadius)
            .opacity(exitAnimationValues.opacity)
            .onChange(of: state.isDismissing) { _, isDismissing in
                guard isDismissing else { return }
                animateExit()
            }
    }

    @ViewBuilder
    private var entranceAnimatedCard: some View {
        switch state.entranceStyle {
        case .bubble:
            bubbleEntrance
        case .unfurl:
            unfurlEntrance
        case .swing:
            swingEntrance
        case .pour:
            pourEntrance
        case .pop:
            popEntrance
        case .slide:
            slideEntrance
        }
    }

    private var shapedCard: some View {
        let silhouette: AnyShape = state.cardShape.shape
        let glowColor = state.theme.accent
        let glowOpacity = state.isNightMode
            ? 0.08
            : (glowIsPulsing ? 0.4 : 0.25)
        let isGlowAnimating = glowIsPulsing && !state.isNightMode

        return card
            .clipShape(silhouette)
            .overlay {
                silhouette
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .background {
                silhouette
                    .fill(glowColor)
                    .opacity(glowOpacity)
                    .blur(radius: 30)
                    .scaleEffect(1.05)
                    .animation(
                        .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isGlowAnimating
                    )
            }
    }

    private var bubbleEntrance: some View {
        let multiplier = state.entranceDurationMultiplier

        return shapedCard
            .keyframeAnimator(
                initialValue: EntranceAnimationValues.bubbleInitial,
                trigger: entranceTrigger
            ) { content, values in
                content
                    .scaleEffect(
                        x: values.scaleX,
                        y: values.scaleY,
                        anchor: .top
                    )
                    .rotationEffect(
                        .degrees(values.rotation),
                        anchor: .top
                    )
                    .offset(x: values.offsetX, y: values.offsetY)
                    .opacity(values.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scaleX) {
                    SpringKeyframe(
                        1.12,
                        duration: 0.28 * multiplier,
                        spring: Spring(
                            duration: 0.28 * multiplier,
                            bounce: 0.10
                        )
                    )
                    SpringKeyframe(
                        0.94,
                        duration: 0.14 * multiplier,
                        spring: Spring(
                            duration: 0.14 * multiplier,
                            bounce: 0.08
                        )
                    )
                    SpringKeyframe(
                        1.03,
                        duration: 0.12 * multiplier,
                        spring: Spring(
                            duration: 0.12 * multiplier,
                            bounce: 0.06
                        )
                    )
                    SpringKeyframe(
                        1.00,
                        duration: 0.10 * multiplier,
                        spring: Spring(
                            duration: 0.10 * multiplier,
                            bounce: 0.04
                        )
                    )
                }

                KeyframeTrack(\.scaleY) {
                    SpringKeyframe(
                        0.88,
                        duration: 0.28 * multiplier,
                        spring: Spring(
                            duration: 0.28 * multiplier,
                            bounce: 0.10
                        )
                    )
                    SpringKeyframe(
                        1.10,
                        duration: 0.14 * multiplier,
                        spring: Spring(
                            duration: 0.14 * multiplier,
                            bounce: 0.08
                        )
                    )
                    SpringKeyframe(
                        0.97,
                        duration: 0.12 * multiplier,
                        spring: Spring(
                            duration: 0.12 * multiplier,
                            bounce: 0.06
                        )
                    )
                    SpringKeyframe(
                        1.00,
                        duration: 0.10 * multiplier,
                        spring: Spring(
                            duration: 0.10 * multiplier,
                            bounce: 0.04
                        )
                    )
                }

                KeyframeTrack(\.offsetY) {
                    SpringKeyframe(
                        12,
                        duration: 0.28 * multiplier,
                        spring: Spring(
                            duration: 0.28 * multiplier,
                            bounce: 0.10
                        )
                    )
                    SpringKeyframe(
                        5,
                        duration: 0.14 * multiplier,
                        spring: Spring(
                            duration: 0.14 * multiplier,
                            bounce: 0.08
                        )
                    )
                    SpringKeyframe(
                        9,
                        duration: 0.12 * multiplier,
                        spring: Spring(
                            duration: 0.12 * multiplier,
                            bounce: 0.06
                        )
                    )
                    SpringKeyframe(
                        8,
                        duration: 0.10 * multiplier,
                        spring: Spring(
                            duration: 0.10 * multiplier,
                            bounce: 0.04
                        )
                    )
                }

                KeyframeTrack(\.opacity) {
                    SpringKeyframe(
                        1,
                        duration: 0.28 * multiplier,
                        spring: Spring(
                            duration: 0.28 * multiplier,
                            bounce: 0
                        )
                    )
                }
            }
    }

    private var unfurlEntrance: some View {
        let multiplier = state.entranceDurationMultiplier

        return shapedCard
            .keyframeAnimator(
                initialValue: EntranceAnimationValues.unfurlInitial,
                trigger: entranceTrigger
            ) { content, values in
                content
                    .scaleEffect(
                        x: values.scaleX,
                        y: values.scaleY,
                        anchor: .top
                    )
                    .rotationEffect(.degrees(values.rotation), anchor: .top)
                    .offset(x: values.offsetX, y: values.offsetY)
                    .opacity(values.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scaleY) {
                    CubicKeyframe(0.20, duration: 0.16 * multiplier)
                    CubicKeyframe(0.78, duration: 0.24 * multiplier)
                    SpringKeyframe(
                        1.06,
                        duration: 0.18 * multiplier,
                        spring: Spring(
                            duration: 0.18 * multiplier,
                            bounce: 0.08
                        )
                    )
                    SpringKeyframe(
                        1,
                        duration: 0.12 * multiplier,
                        spring: Spring(
                            duration: 0.12 * multiplier,
                            bounce: 0.04
                        )
                    )
                }

                KeyframeTrack(\.offsetY) {
                    CubicKeyframe(-6, duration: 0.16 * multiplier)
                    CubicKeyframe(7, duration: 0.24 * multiplier)
                    SpringKeyframe(
                        9,
                        duration: 0.18 * multiplier,
                        spring: Spring(
                            duration: 0.18 * multiplier,
                            bounce: 0.06
                        )
                    )
                    SpringKeyframe(
                        8,
                        duration: 0.12 * multiplier,
                        spring: Spring(
                            duration: 0.12 * multiplier,
                            bounce: 0.03
                        )
                    )
                }
            }
    }

    private var swingEntrance: some View {
        let multiplier = state.entranceDurationMultiplier

        return shapedCard
            .keyframeAnimator(
                initialValue: EntranceAnimationValues.swingInitial,
                trigger: entranceTrigger
            ) { content, values in
                content
                    .scaleEffect(
                        x: values.scaleX,
                        y: values.scaleY,
                        anchor: .topLeading
                    )
                    .rotationEffect(
                        .degrees(values.rotation),
                        anchor: .topLeading
                    )
                    .offset(x: values.offsetX, y: values.offsetY)
                    .opacity(values.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.offsetX) {
                    CubicKeyframe(10, duration: 0.28 * multiplier)
                    CubicKeyframe(-4, duration: 0.20 * multiplier)
                    CubicKeyframe(0, duration: 0.17 * multiplier)
                }

                KeyframeTrack(\.offsetY) {
                    LinearKeyframe(8, duration: 0.65 * multiplier)
                }

                KeyframeTrack(\.rotation) {
                    CubicKeyframe(3.5, duration: 0.28 * multiplier)
                    CubicKeyframe(-1.5, duration: 0.20 * multiplier)
                    CubicKeyframe(0, duration: 0.17 * multiplier)
                }

                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.18 * multiplier)
                }
            }
    }

    private var pourEntrance: some View {
        let multiplier = state.entranceDurationMultiplier

        return shapedCard
            .keyframeAnimator(
                initialValue: EntranceAnimationValues.pourInitial,
                trigger: entranceTrigger
            ) { content, values in
                content
                    .scaleEffect(
                        x: values.scaleX,
                        y: values.scaleY,
                        anchor: .top
                    )
                    .rotationEffect(.degrees(values.rotation), anchor: .top)
                    .offset(x: values.offsetX, y: values.offsetY)
                    .opacity(values.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scaleX) {
                    CubicKeyframe(0.72, duration: 0.18 * multiplier)
                    SpringKeyframe(
                        1.12,
                        duration: 0.22 * multiplier,
                        spring: Spring(
                            duration: 0.22 * multiplier,
                            bounce: 0.12
                        )
                    )
                    SpringKeyframe(
                        0.96,
                        duration: 0.16 * multiplier,
                        spring: Spring(
                            duration: 0.16 * multiplier,
                            bounce: 0.08
                        )
                    )
                    SpringKeyframe(
                        1,
                        duration: 0.12 * multiplier,
                        spring: Spring(
                            duration: 0.12 * multiplier,
                            bounce: 0.04
                        )
                    )
                }

                KeyframeTrack(\.scaleY) {
                    CubicKeyframe(0.92, duration: 0.18 * multiplier)
                    SpringKeyframe(
                        0.76,
                        duration: 0.22 * multiplier,
                        spring: Spring(
                            duration: 0.22 * multiplier,
                            bounce: 0.10
                        )
                    )
                    SpringKeyframe(
                        1.08,
                        duration: 0.16 * multiplier,
                        spring: Spring(
                            duration: 0.16 * multiplier,
                            bounce: 0.08
                        )
                    )
                    SpringKeyframe(
                        1,
                        duration: 0.12 * multiplier,
                        spring: Spring(
                            duration: 0.12 * multiplier,
                            bounce: 0.04
                        )
                    )
                }

                KeyframeTrack(\.offsetY) {
                    CubicKeyframe(4, duration: 0.18 * multiplier)
                    SpringKeyframe(
                        10,
                        duration: 0.22 * multiplier,
                        spring: Spring(
                            duration: 0.22 * multiplier,
                            bounce: 0.08
                        )
                    )
                    SpringKeyframe(
                        7,
                        duration: 0.16 * multiplier,
                        spring: Spring(
                            duration: 0.16 * multiplier,
                            bounce: 0.05
                        )
                    )
                    SpringKeyframe(
                        8,
                        duration: 0.12 * multiplier,
                        spring: Spring(
                            duration: 0.12 * multiplier,
                            bounce: 0.03
                        )
                    )
                }

                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.15 * multiplier)
                }
            }
    }

    private var popEntrance: some View {
        let multiplier = state.entranceDurationMultiplier

        return shapedCard
            .keyframeAnimator(
                initialValue: EntranceAnimationValues.popInitial,
                trigger: entranceTrigger
            ) { content, values in
                content
                    .scaleEffect(
                        x: values.scaleX,
                        y: values.scaleY,
                        anchor: .center
                    )
                    .rotationEffect(.degrees(values.rotation))
                    .offset(x: values.offsetX, y: values.offsetY)
                    .opacity(values.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scaleX) {
                    SpringKeyframe(
                        1.15,
                        duration: 0.18 * multiplier,
                        spring: Spring(
                            duration: 0.18 * multiplier,
                            bounce: 0.32
                        )
                    )
                    SpringKeyframe(
                        1,
                        duration: 0.17 * multiplier,
                        spring: Spring(
                            duration: 0.17 * multiplier,
                            bounce: 0.12
                        )
                    )
                }

                KeyframeTrack(\.scaleY) {
                    SpringKeyframe(
                        1.15,
                        duration: 0.18 * multiplier,
                        spring: Spring(
                            duration: 0.18 * multiplier,
                            bounce: 0.32
                        )
                    )
                    SpringKeyframe(
                        1,
                        duration: 0.17 * multiplier,
                        spring: Spring(
                            duration: 0.17 * multiplier,
                            bounce: 0.12
                        )
                    )
                }

                KeyframeTrack(\.offsetY) {
                    LinearKeyframe(8, duration: 0.35 * multiplier)
                }
            }
    }

    private var slideEntrance: some View {
        let multiplier = state.entranceDurationMultiplier

        return shapedCard
            .keyframeAnimator(
                initialValue: EntranceAnimationValues.slideInitial,
                trigger: entranceTrigger
            ) { content, values in
                content
                    .scaleEffect(
                        x: values.scaleX,
                        y: values.scaleY,
                        anchor: .center
                    )
                    .rotationEffect(.degrees(values.rotation))
                    .offset(x: values.offsetX, y: values.offsetY)
                    .opacity(values.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.offsetX) {
                    CubicKeyframe(-60, duration: 0.22 * multiplier)
                    CubicKeyframe(-12, duration: 0.12 * multiplier)
                    CubicKeyframe(3, duration: 0.10 * multiplier)
                    CubicKeyframe(0, duration: 0.10 * multiplier)
                }

                KeyframeTrack(\.offsetY) {
                    LinearKeyframe(8, duration: 0.54 * multiplier)
                }

                KeyframeTrack(\.rotation) {
                    CubicKeyframe(-2.5, duration: 0.22 * multiplier)
                    CubicKeyframe(0.8, duration: 0.12 * multiplier)
                    CubicKeyframe(-0.2, duration: 0.10 * multiplier)
                    CubicKeyframe(0, duration: 0.10 * multiplier)
                }

            }
    }

    private func animateExit() {
        switch state.exitStyle {
        case .shrinkToNotch:
            withAnimation(.easeIn(duration: state.exitStyle.duration)) {
                exitAnimationValues.scaleX = 0.30
                exitAnimationValues.scaleY = 0.15
                exitAnimationValues.offsetY = -28
                exitAnimationValues.opacity = 0
            }

        case .fall:
            withAnimation(
                .timingCurve(
                    0.55,
                    0,
                    0.95,
                    0.45,
                    duration: state.exitStyle.duration
                )
            ) {
                exitAnimationValues.offsetY = HUDLayout.panelSize.height
                    + state.cardSize.height
                exitAnimationValues.rotation = 7
            }

        case .dissolve:
            withAnimation(.easeInOut(duration: state.exitStyle.duration)) {
                exitAnimationValues.blurRadius = 20
                exitAnimationValues.opacity = 0
            }
        }
    }

    private var card: some View {
        cardContent
            .frame(
                width: state.cardSize.width,
                height: cardHeight
            )
            .background {
                ZStack {
                    driftingBackground

                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.16)
                }
            }
            .overlay(alignment: .bottom) {
                if !state.isInformational {
                    cycleIndicator
                        .padding(.bottom, cycleIndicatorBottomPadding)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if state.currentStreak >= 3 {
                    streakIndicator
                        .padding(.trailing, 12)
                        .padding(.bottom, 9)
                }
            }
    }

    @ViewBuilder
    private var cardContent: some View {
        if state.cardSizeVariant == .compact {
            compactStaticContent
        } else {
            staticContent
        }
    }

    private var staticContent: some View {
        HStack(spacing: contentSpacing) {
            animatedEye

            VStack(alignment: .leading, spacing: 3) {
                animatedWords(
                    state.message.title,
                    size: 17,
                    weight: .semibold
                )

                animatedSubtitle(
                    size: 13,
                    lineLimit: 1,
                    minimumScaleFactor: 0.85
                )
            }

            Spacer(minLength: HUDLayout.standardSpacerMinimumWidth)

            countdownRing
        }
        .padding(.leading, horizontalContentPadding)
        .padding(.trailing, trailingContentPadding)
    }

    private var compactStaticContent: some View {
        HStack(spacing: 10) {
            animatedEye

            VStack(alignment: .leading, spacing: 4) {
                Text(state.message.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)

                animatedSubtitle(
                    size: 12,
                    lineLimit: 2,
                    minimumScaleFactor: 0.82
                )
            }
            .foregroundStyle(state.theme.foreground)
            .opacity(entranceTrigger > 0 ? 1 : 0)
            .offset(y: entranceTrigger > 0 ? 0 : 6)
            .animation(
                .easeOut(
                    duration: 0.24 * state.entranceDurationMultiplier
                )
                .delay(0.25 * state.entranceDurationMultiplier),
                value: entranceTrigger
            )
            .animation(
                .easeInOut(duration: 0.3),
                value: state.isHeld
            )

            Spacer(minLength: 2)

            countdownRing
        }
        .padding(.leading, horizontalContentPadding)
        .padding(.trailing, trailingContentPadding)
        .padding(.bottom, 6)
    }

    private func animatedWords(
        _ text: String,
        size: CGFloat,
        weight: Font.Weight,
        startingAt startingIndex: Int = 0
    ) -> some View {
        let words = text.split(whereSeparator: { $0.isWhitespace })

        return HStack(spacing: size * 0.24) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                Text(String(word))
                    .font(.system(size: size, weight: weight))
                    .foregroundStyle(state.theme.foreground)
                    .lineLimit(1)
                    .opacity(entranceTrigger > 0 ? 1 : 0)
                    .offset(y: entranceTrigger > 0 ? 0 : 6)
                    .animation(
                        .easeOut(
                            duration: 0.24
                                * state.entranceDurationMultiplier
                        )
                            .delay(
                                (
                                    0.25
                                        + Double(startingIndex + index) * 0.06
                                ) * state.entranceDurationMultiplier
                            ),
                        value: entranceTrigger
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private func animatedSubtitle(
        size: CGFloat,
        lineLimit: Int,
        minimumScaleFactor: CGFloat
    ) -> some View {
        Text(state.displayedSubtitle)
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(state.theme.foreground)
            .lineLimit(lineLimit)
            .minimumScaleFactor(minimumScaleFactor)
            .contentTransition(.opacity)
            .opacity(entranceTrigger > 0 ? 1 : 0)
            .offset(y: entranceTrigger > 0 ? 0 : 6)
            .animation(
                .easeOut(
                    duration: 0.24 * state.entranceDurationMultiplier
                )
                .delay(
                    0.25 * state.entranceDurationMultiplier
                ),
                value: entranceTrigger
            )
            .animation(
                .easeInOut(duration: 0.4),
                value: state.displayedSubtitle
            )
    }

    private var cycleIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { index in
                if index < state.completedBreaksInCycle {
                    Circle()
                        .fill(state.theme.foreground.opacity(0.9))
                        .frame(width: 4, height: 4)
                } else {
                    Circle()
                        .strokeBorder(state.theme.foreground.opacity(0.4), lineWidth: 1)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var streakIndicator: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
            Text("\(state.currentStreak)")
                .monospacedDigit()
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(state.theme.foreground.opacity(0.6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(state.currentStreak) day streak")
    }

    private var cardHeight: CGFloat {
        state.cardHeight
    }

    private var horizontalContentPadding: CGFloat {
        switch state.cardSizeVariant {
        case .standard:
            return HUDLayout.standardHorizontalContentPadding
        case .wide:
            return 18
        case .compact:
            return 14
        }
    }

    private var trailingContentPadding: CGFloat {
        if state.currentStreak >= 3, state.cardSizeVariant == .wide {
            return 56
        }

        return horizontalContentPadding
    }

    private var contentSpacing: CGFloat {
        state.cardSizeVariant == .compact
            ? 10
            : HUDLayout.standardContentSpacing
    }

    private var cycleIndicatorBottomPadding: CGFloat {
        state.cardSizeVariant == .wide ? 4 : 10
    }

    private var countdownDiameter: CGFloat {
        switch state.cardSizeVariant {
        case .standard:
            return HUDLayout.standardCountdownDiameter
        case .wide:
            return 40
        case .compact:
            return 44
        }
    }

    private var isInFinalThreeSeconds: Bool {
        state.remainingSeconds < 3
    }

    private var driftingBackground: LinearGradient {
        let elapsedProgress = 1 - state.progress
        let angle = (Double.pi / 4)
            + (elapsedProgress * 2 * Double.pi / 3)
        let radius: CGFloat = 0.72
        let xOffset = CGFloat(cos(angle)) * radius
        let yOffset = CGFloat(sin(angle)) * radius

        return state.theme.gradient(
            startPoint: UnitPoint(
                x: 0.5 - xOffset,
                y: 0.5 - yOffset
            ),
            endPoint: UnitPoint(
                x: 0.5 + xOffset,
                y: 0.5 + yOffset
            )
        )
    }

    private var cardAccessibilityLabel: String {
        if state.isInformational {
            return "\(state.message.title). \(state.displayedSubtitle)."
        }

        let cycleDescription = "\(state.completedBreaksInCycle) of 4 breaks completed"
        let streakDescription = state.currentStreak >= 3
            ? " \(state.currentStreak) day streak."
            : ""

        return "\(state.message.title). \(state.displayedSubtitle). \(cycleDescription).\(streakDescription)"
    }

    @ViewBuilder
    private var animatedEye: some View {
        if #available(macOS 14.0, *) {
            eyeIcon
                .symbolEffect(.pulse, value: state.blinkTrigger)
        } else {
            eyeIcon
                .scaleEffect(x: 1, y: fallbackBlinkScaleY)
                .onChange(of: state.blinkTrigger) { _ in
                    animateFallbackBlink()
                }
        }
    }

    private var eyeIcon: some View {
        ZStack {
            Image(systemName: "eye")
                .opacity(state.isHeld ? 0 : 1)

            Image(systemName: "eye.trianglebadge.exclamationmark")
                .opacity(state.isHeld ? 1 : 0)
        }
        .font(.system(size: 26, weight: .semibold))
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(state.theme.foreground)
        .frame(width: HUDLayout.eyeWidth, height: HUDLayout.eyeWidth)
        .animation(.easeInOut(duration: 0.3), value: state.isHeld)
    }

    private func animateFallbackBlink() {
        withAnimation(.easeInOut(duration: 0.09)) {
            fallbackBlinkScaleY = 0.15
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.easeInOut(duration: 0.09)) {
                fallbackBlinkScaleY = 1
            }
        }
    }

    private var countdownRing: some View {
        let lineWidth: CGFloat = isInFinalThreeSeconds ? 5 : 3

        return ZStack {
            Circle()
                .stroke(
                    state.theme.foreground.opacity(0.16),
                    lineWidth: lineWidth
                )

            Circle()
                .trim(from: 0, to: state.progress)
                .stroke(
                    state.countdownAccent,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .animation(
                    .easeInOut(duration: 0.4),
                    value: state.focusExercisePhase
                )
                .rotationEffect(.degrees(-90))
                .opacity(state.isHeld ? 0.35 : (state.isPaused ? 0.5 : 1))
                .animation(
                    .easeInOut(duration: 0.3),
                    value: state.isHeld
                )

            Text(state.displayedTime)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(state.theme.foreground)
                .contentTransition(.numericText())
        }
        .frame(width: countdownDiameter, height: countdownDiameter)
        .animation(
            .easeInOut(duration: 0.4),
            value: isInFinalThreeSeconds
        )
        .animation(.linear(duration: 0.05), value: state.progress)
        .accessibilityLabel(
            state.isHeld
                ? "Countdown held, \(state.displayedSeconds) seconds remaining"
                : "\(state.displayedSeconds) seconds remaining"
        )
    }
}
