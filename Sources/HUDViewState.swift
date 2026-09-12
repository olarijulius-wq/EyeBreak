import AppKit
import Combine
import Foundation
import SwiftUI

enum CardSizeVariant: Equatable {
    case standard
    case wide
    case compact
}

enum HUDLayout {
    // The transparent margin keeps the blurred glow visible through the
    // widest card's entrance stretch and a full 120-point downward drag.
    static let panelSize = CGSize(width: 780, height: 344)
    static let minimumCardWidth: CGFloat = 360
    static let preferredStandardCardWidth: CGFloat = 460
    static let maximumCardWidth: CGFloat = 600
    static let wideCardWidth: CGFloat = 600
    static let compactCardWidth: CGFloat = 320
    static let standardCardHeight: CGFloat = 56
    static let wideCardHeight: CGFloat = 48
    static let compactCardHeight: CGFloat = 72
    static let notchedCardTopPadding: CGFloat = 32
    static let noNotchCardTopInset: CGFloat = 12
    static let eyeIconFontSize: CGFloat = 20
    static let eyeWidth: CGFloat = 24
    static let titleFontSize: CGFloat = 14
    static let subtitleFontSize: CGFloat = 11
    static let titleSubtitleSpacing: CGFloat = 1
    static let titleBadgeSpacing: CGFloat = 3
    static let streakIndicatorSpacing: CGFloat = 3
    static let streakIndicatorFontSize: CGFloat = 11
    static let streakIconEstimatedWidth: CGFloat = 11
    static let standardContentSpacing: CGFloat = 12
    static let standardHorizontalContentPadding: CGFloat = 18
    static let standardCountdownDiameter: CGFloat = 34
    static let countdownStrokeWidth: CGFloat = 2.5
    static let countdownNumberFontSize: CGFloat = 11
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

    private static let deepWorkBundleIdentifierFragments = [
        "xcode",
        "terminal",
        "iterm",
        "code",
        "ghostty"
    ]

    let duration: TimeInterval
    let message: (title: String, subtitle: String)
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
        let selectedMessage: (title: String, subtitle: String)

        if let messageOverride {
            selectedMessage = messageOverride
        } else {
            let messagePool = Self.messagePool(
                date: date,
                calendar: calendar,
                frontmostApplicationBundleIdentifier: frontmostApplicationBundleIdentifier
            )
            selectedMessage = messagePool.randomElement() ?? messagePool[0]
        }

        let resolvedCurrentStreak = max(0, currentStreak)
        message = selectedMessage
        standardNaturalCardWidth = Self.naturalCardWidth(
            for: selectedMessage,
            currentStreak: resolvedCurrentStreak
        )
        focusExerciseNaturalCardWidth = Self.naturalCardWidth(
            for: selectedMessage,
            additionalSubtitles: FocusExercisePhase.allCases.map {
                $0.subtitle
            },
            currentStreak: resolvedCurrentStreak
        )
        self.currentStreak = resolvedCurrentStreak
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
                case .swing, .pour, .pop, .slide, .pixels,
                     .blinds, .clipwipe, .doors, .iris, .shutter,
                     .staggerwipe, .wipe:
                    return true
                }
            }
        let selectedEntranceStyle = entranceStyles.randomElement() ?? .slide
        entranceStyle = selectedEntranceStyle

        if let matchingExitStyle = selectedEntranceStyle.matchingExitStyle {
            exitStyle = matchingExitStyle
        } else {
            let legacyExitStyles: [ExitStyle] = [
                .shrinkToNotch,
                .fall,
                .dissolve,
                .pixels
            ]
            exitStyle = legacyExitStyles.randomElement() ?? .shrinkToNotch
        }

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
        date: Date,
        calendar: Calendar,
        frontmostApplicationBundleIdentifier: String?
    ) -> [(title: String, subtitle: String)] {
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
        additionalSubtitles: [String] = [],
        currentStreak: Int
    ) -> CGFloat {
        let titleWidth = naturalTextWidth(
            message.title,
            size: HUDLayout.titleFontSize,
            weight: .semibold
        )
        let streakWidth: CGFloat

        if currentStreak >= 3 {
            let countWidth = naturalTextWidth(
                String(currentStreak),
                size: HUDLayout.streakIndicatorFontSize,
                weight: .medium
            )
            streakWidth = HUDLayout.titleBadgeSpacing
                + HUDLayout.streakIconEstimatedWidth
                + HUDLayout.streakIndicatorSpacing
                + countWidth
        } else {
            streakWidth = 0
        }

        let subtitleWidth = ([message.subtitle] + additionalSubtitles)
            .map {
                naturalTextWidth(
                    $0,
                    size: HUDLayout.subtitleFontSize,
                    weight: .regular
                )
            }
            .max() ?? 0
        let heldSubtitleWidth = naturalTextWidth(
            heldSubtitle,
            size: HUDLayout.subtitleFontSize,
            weight: .regular
        )
        let textWidth = max(
            titleWidth + streakWidth,
            subtitleWidth,
            heldSubtitleWidth
        )
        let hStackSpacing = HUDLayout.standardContentSpacing * 2

        return ceil(
            (HUDLayout.standardHorizontalContentPadding * 2)
                + HUDLayout.eyeWidth
                + textWidth
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

        return HUDLayout.standardCardHeight
    }

    var cardSize: CGSize {
        switch cardSizeVariant {
        case .wide:
            return CGSize(
                width: HUDLayout.wideCardWidth,
                height: HUDLayout.wideCardHeight
            )
        case .compact:
            return CGSize(
                width: HUDLayout.compactCardWidth,
                height: HUDLayout.compactCardHeight
            )
        case .standard:
            break
        }

        let naturalCardWidth = showsFocusExercise
            ? focusExerciseNaturalCardWidth
            : standardNaturalCardWidth
        let preferredWidth = max(
            naturalCardWidth,
            HUDLayout.preferredStandardCardWidth
        )
        let width = min(
            max(preferredWidth, HUDLayout.minimumCardWidth),
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
        switch entranceStyle {
        case .pixels, .blinds, .clipwipe, .doors, .iris, .shutter,
             .staggerwipe, .wipe:
            return 1
        case .bubble, .unfurl, .swing, .pour, .pop, .slide:
            return isSlowMotionEntrance ? 2.5 : 1
        }
    }

    var hasCompletedEntrance: Bool {
        guard let entranceStartedAt else { return false }

        return Date().timeIntervalSince(entranceStartedAt)
            >= entranceAnimationDuration
    }

    private var entranceAnimationDuration: TimeInterval {
        if case .pixels = entranceStyle {
            return PixelTransition.duration(
                columnCount: PixelTransition.columnCount(
                    for: cardSize.width
                )
            )
        }

        return entranceStyle.duration * entranceDurationMultiplier
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
        guard !isHeld, showsFocusExercise else {
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

    func triggerBlink() {
        blinkTrigger += 1
    }

    func markEntranceStarted() {
        entranceStartedAt = Date()
    }
}
