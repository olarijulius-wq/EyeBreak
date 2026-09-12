import Foundation
import SwiftUI

enum CardHoverHysteresis {
    static let trackingPadding: CGFloat = 16
    static let exitPadding: CGFloat = 20

    static var contentShapeOutset: CGFloat {
        max(0, exitPadding - trackingPadding)
    }

    static func restingBounds(for cardSize: CGSize) -> CGRect {
        CGRect(
            x: trackingPadding,
            y: trackingPadding,
            width: cardSize.width,
            height: cardSize.height
        )
    }

    static func resolvedState(
        currentState: Bool,
        location: CGPoint,
        cardSize: CGSize
    ) -> Bool {
        let restingBounds = restingBounds(for: cardSize)

        if currentState {
            return containsIncludingEdges(
                location,
                in: restingBounds.insetBy(
                    dx: -exitPadding,
                    dy: -exitPadding
                )
            )
        }

        return containsInterior(location, in: restingBounds)
    }

    private static func containsInterior(
        _ point: CGPoint,
        in bounds: CGRect
    ) -> Bool {
        point.x > bounds.minX
            && point.x < bounds.maxX
            && point.y > bounds.minY
            && point.y < bounds.maxY
    }

    private static func containsIncludingEdges(
        _ point: CGPoint,
        in bounds: CGRect
    ) -> Bool {
        point.x >= bounds.minX
            && point.x <= bounds.maxX
            && point.y >= bounds.minY
            && point.y <= bounds.maxY
    }
}

struct HUDView: View {
    private static let tiltEdgeInset: CGFloat = 8

    @ObservedObject var state: HUDViewState
    let onDismiss: () -> Void
    let onHoverChanged: (Bool) -> Void

    @State var entranceTrigger = 0
    @State var glowIsPulsing = false
    @State private var fallbackBlinkScaleY: CGFloat = 1
    @State private var dragOffset: CGFloat = 0
    @State private var tiltX = 0.0
    @State private var tiltY = 0.0
    @State private var isCardHovered = false
    @State var pixelEntranceTask: Task<Void, Never>?
    @State var pixelEntranceStarted = false
    @State var pixelContentIsVisible = false
    @State var isAssembled = false
    @State var pixelExitStarted = false
    @State var maskExitStarted = false
    @State var pixelAnimationSeed = UInt64.random(
        in: 0...UInt64.max
    )
    @State var exitAnimationValues = ExitAnimationValues()

    var body: some View {
        hoverTrackingContainer
            .offset(y: hoverContainerOffsetY)
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
                    startPixelEntranceIfNeeded()
                }
            }
            .onDisappear {
                pixelEntranceTask?.cancel()
                pixelEntranceTask = nil
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

    private var hoverTrackingContainer: some View {
        // Entrance animations include a resting Y offset. Cancel it here
        // so the fixed container stays centered on the resting card. This
        // wrapper intentionally has no rendered background; its shape is
        // exclusively for stable hover hit testing.
        hoverAnimatedCard
            .offset(y: -state.entranceStyle.restingOffsetY)
            .frame(
                width: state.cardSize.width
                    + (CardHoverHysteresis.trackingPadding * 2),
                height: cardHeight
                    + (CardHoverHysteresis.trackingPadding * 2)
            )
            .contentShape(
                // The frame supplies 16pt; the stable shape supplies the final
                // 4pt needed to observe the 20pt exit threshold.
                Rectangle().inset(
                    by: -CardHoverHysteresis.contentShapeOutset
                )
            )
            .onContinuousHover(coordinateSpace: .local) { phase in
                handleContinuousHover(phase)
            }
    }

    private var hoverAnimatedCard: some View {
        animatedCard
            .scaleEffect(isInFinalThreeSeconds ? 0.97 : 1)
            .scaleEffect(isCardHovered ? 1.03 : 1)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.5),
                value: isCardHovered
            )
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
            .gesture(
                cardDragGesture.exclusively(before: cardTapGesture)
            )
            .help(
                state.isInformational
                    ? ""
                    : "Right-click to snooze breaks for 30 minutes"
            )
    }

    private var hoverContainerOffsetY: CGFloat {
        state.restingCardTopInset - CardHoverHysteresis.trackingPadding
    }

    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { value in
                guard
                    !state.isDismissing,
                    !state.isInformational
                else {
                    return
                }
                dragOffset = rubberBandOffset(for: value.translation.height)
            }
            .onEnded { _ in
                guard !state.isInformational else {
                    return
                }

                withAnimation(
                    .spring(response: 0.4, dampingFraction: 0.55)
                ) {
                    dragOffset = 0
                }
            }
    }

    private var cardTapGesture: some Gesture {
        TapGesture()
            .onEnded {
                guard
                    !state.isDismissing,
                    !state.isInformational
                else {
                    return
                }

                onDismiss()
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

    private func handleContinuousHover(_ phase: HoverPhase) {
        switch phase {
        case .active(let location):
            let resolvedHoverState = CardHoverHysteresis.resolvedState(
                currentState: isCardHovered,
                location: location,
                cardSize: state.cardSize
            )
            setCardHovered(resolvedHoverState)
            updateTilt(
                at: location,
                isHovering: resolvedHoverState
            )

        case .ended:
            setCardHovered(false)
            resetTilt()
        }
    }

    private func setCardHovered(_ isHovering: Bool) {
        guard isCardHovered != isHovering else { return }

        isCardHovered = isHovering
        onHoverChanged(isHovering)
    }

    private func updateTilt(
        at location: CGPoint,
        isHovering: Bool
    ) {
        guard isHovering else {
            resetTilt()
            return
        }

        let locationInCard = CGPoint(
            x: location.x - CardHoverHysteresis.trackingPadding,
            y: location.y - CardHoverHysteresis.trackingPadding
        )
        let horizontalPosition = normalizedTiltPosition(
            locationInCard.x,
            length: state.cardSize.width
        )
        let verticalPosition = normalizedTiltPosition(
            locationInCard.y,
            length: cardHeight
        )

        tiltX = -Double(verticalPosition) * 4
        tiltY = Double(horizontalPosition) * 4
    }

    private func resetTilt() {
        guard tiltX != 0 || tiltY != 0 else { return }

        withAnimation(
            .spring(response: 0.35, dampingFraction: 0.7)
        ) {
            tiltX = 0
            tiltY = 0
        }
    }

    private func normalizedTiltPosition(
        _ position: CGFloat,
        length: CGFloat
    ) -> CGFloat {
        let edgeInset = min(Self.tiltEdgeInset, length / 2)
        let minimumPosition = edgeInset
        let maximumPosition = length - edgeInset

        guard maximumPosition > minimumPosition else {
            return 0
        }

        let clampedPosition = min(
            max(position, minimumPosition),
            maximumPosition
        )
        return ((clampedPosition - minimumPosition)
            / (maximumPosition - minimumPosition)) * 2 - 1
    }

    var card: some View {
        cardForeground
            .background {
                cardBackground
            }
    }

    var cardSilhouette: AnyShape {
        state.cardShape.shape
    }

    var cardForeground: some View {
        cardContent
            .frame(
                width: state.cardSize.width,
                height: cardHeight
            )
    }

    private var cardBackground: some View {
        let silhouette = cardSilhouette

        return ZStack {
            silhouette
                .fill(driftingBackground)

            silhouette
                .fill(.ultraThinMaterial)
                .opacity(0.16)
        }
    }

    private var cardContent: some View {
        HStack(spacing: HUDLayout.standardContentSpacing) {
            animatedEye

            VStack(
                alignment: .leading,
                spacing: HUDLayout.titleSubtitleSpacing
            ) {
                HStack(spacing: HUDLayout.titleBadgeSpacing) {
                    cardTitle

                    if state.currentStreak >= 3 {
                        streakIndicator
                    }
                }

                animatedSubtitle(
                    size: HUDLayout.subtitleFontSize,
                    lineLimit: state.cardSizeVariant == .compact ? 2 : 1,
                    minimumScaleFactor: state.cardSizeVariant == .compact
                        ? 0.82
                        : 0.85
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            countdownRing
        }
        .padding(.horizontal, HUDLayout.standardHorizontalContentPadding)
    }

    @ViewBuilder
    private var cardTitle: some View {
        if state.cardSizeVariant == .compact {
            rollingTitle(
                state.message.title,
                size: HUDLayout.titleFontSize,
                weight: .semibold,
                animatesEntranceByWord: false
            )
            .opacity(entranceTextIsVisible ? 1 : 0)
            .offset(y: entranceTextIsVisible ? 0 : 6)
            .animation(
                textEntranceAnimation(delay: 0.25),
                value: entranceTrigger
            )
        } else {
            animatedWords(
                state.message.title,
                size: HUDLayout.titleFontSize,
                weight: .semibold
            )
        }
    }

    private func animatedWords(
        _ text: String,
        size: CGFloat,
        weight: Font.Weight,
        startingAt startingIndex: Int = 0
    ) -> some View {
        rollingTitle(
            text,
            size: size,
            weight: weight,
            startingAt: startingIndex,
            animatesEntranceByWord: true
        )
    }

    private func rollingTitle(
        _ text: String,
        size: CGFloat,
        weight: Font.Weight,
        startingAt startingIndex: Int = 0,
        animatesEntranceByWord: Bool
    ) -> some View {
        let lineHeight = ceil(size * 1.25)

        return ZStack(alignment: .leading) {
            rollingTitleLine(
                text,
                size: size,
                weight: weight,
                startingAt: startingIndex,
                lineHeight: lineHeight,
                isReplacement: false,
                animatesEntranceByWord: animatesEntranceByWord
            )

            rollingTitleLine(
                state.isHeld ? "Timer waiting" : "Still counting",
                size: size,
                weight: weight,
                startingAt: startingIndex,
                lineHeight: lineHeight,
                isReplacement: true,
                animatesEntranceByWord: animatesEntranceByWord
            )
        }
        .frame(height: lineHeight)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private func rollingTitleLine(
        _ text: String,
        size: CGFloat,
        weight: Font.Weight,
        startingAt startingIndex: Int,
        lineHeight: CGFloat,
        isReplacement: Bool,
        animatesEntranceByWord: Bool
    ) -> some View {
        let words = text.split(whereSeparator: { $0.isWhitespace })

        return HStack(spacing: size * 0.24) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let characterStart = words.prefix(index).reduce(0) {
                    $0 + $1.count + 1
                }

                HStack(spacing: 0) {
                    ForEach(
                        Array(String(word).enumerated()),
                        id: \.offset
                    ) { characterIndex, character in
                        Text(String(character))
                            .offset(
                                y: rollingCharacterOffset(
                                    lineHeight: lineHeight,
                                    isReplacement: isReplacement
                                )
                            )
                            .animation(
                                .easeInOut(duration: 0.22)
                                    .delay(
                                        Double(
                                            characterStart + characterIndex
                                        ) * 0.02
                                    ),
                                value: isCardHovered
                            )
                    }
                }
                    .opacity(
                        animatesEntranceByWord
                            ? (entranceTextIsVisible ? 1 : 0)
                            : 1
                    )
                    .offset(
                        y: animatesEntranceByWord
                            && !entranceTextIsVisible
                            ? 6
                            : 0
                    )
                    .animation(
                        animatesEntranceByWord
                            ? textEntranceAnimation(
                                delay: 0.25
                                    + Double(startingIndex + index) * 0.06
                            )
                            : nil,
                        value: entranceTrigger
                    )
            }
        }
        .font(.system(size: size, weight: weight))
        .foregroundStyle(state.theme.foreground)
        .lineLimit(1)
    }

    private func rollingCharacterOffset(
        lineHeight: CGFloat,
        isReplacement: Bool
    ) -> CGFloat {
        if isReplacement {
            return isCardHovered ? 0 : lineHeight
        }

        return isCardHovered ? -lineHeight : 0
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
            .opacity(entranceTextIsVisible ? 1 : 0)
            .offset(y: entranceTextIsVisible ? 0 : 6)
            .animation(
                textEntranceAnimation(delay: 0.25),
                value: entranceTrigger
            )
            .animation(
                .easeInOut(duration: 0.3),
                value: state.displayedSubtitle
            )
    }

    private var entranceTextIsVisible: Bool {
        if case .pixels = state.entranceStyle {
            return true
        }

        if maskEntranceStyle != nil {
            return true
        }

        return entranceTrigger > 0
    }

    private func textEntranceAnimation(delay: TimeInterval) -> Animation? {
        if case .pixels = state.entranceStyle {
            return nil
        }

        guard maskEntranceStyle == nil else { return nil }

        return .easeOut(
            duration: 0.24 * state.entranceDurationMultiplier
        )
        .delay(delay * state.entranceDurationMultiplier)
    }

    private var streakIndicator: some View {
        HStack(spacing: HUDLayout.streakIndicatorSpacing) {
            Image(systemName: "flame.fill")
            Text("\(state.currentStreak)")
                .monospacedDigit()
        }
        .font(
            .system(
                size: HUDLayout.streakIndicatorFontSize,
                weight: .medium
            )
        )
        .foregroundStyle(state.theme.foreground.opacity(0.6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(state.currentStreak) day streak")
    }

    var cardHeight: CGFloat {
        state.cardHeight
    }

    private var isInFinalThreeSeconds: Bool {
        state.remainingSeconds < 3
    }

    var driftingBackground: LinearGradient {
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

        let streakDescription = state.currentStreak >= 3
            ? " \(state.currentStreak) day streak."
            : ""

        return "\(state.message.title). \(state.displayedSubtitle).\(streakDescription)"
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
        .font(.system(size: HUDLayout.eyeIconFontSize, weight: .semibold))
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
        let lineWidth = HUDLayout.countdownStrokeWidth

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

            Text("\(state.displayedSeconds)")
                .font(
                    .system(
                        size: HUDLayout.countdownNumberFontSize,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .monospacedDigit()
                .foregroundStyle(state.theme.foreground)
                .contentTransition(.numericText())
        }
        .frame(
            width: HUDLayout.standardCountdownDiameter,
            height: HUDLayout.standardCountdownDiameter
        )
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
