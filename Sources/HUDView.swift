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

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var reducedMotionWasEnabled = false
    @ObservedObject var state: HUDViewState
    let onDismiss: () -> Void
    let onHoverChanged: (Bool) -> Void

    @State var entranceTrigger = 0
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

    // Once this presentation takes the fade path, keep it there. Inserting a
    // keyframe/pixel entrance halfway through a break can hide assembled content.
    var usesReducedMotion: Bool {
        reduceMotion || reducedMotionWasEnabled
    }

    var body: some View {
        hoverTrackingContainer
            .offset(y: hoverContainerOffsetY)
            .frame(
                width: HUDLayout.panelSize.width,
                height: HUDLayout.panelSize.height,
                alignment: .top
            )
            .preferredColorScheme(.dark)
            .onAppear {
                reducedMotionWasEnabled = reducedMotionWasEnabled || reduceMotion
                DispatchQueue.main.async {
                    guard !state.isDismissing else { return }
                    state.markEntranceStarted()
                    entranceTrigger += 1
                    startPixelEntranceIfNeeded()
                }
            }
            .onChange(of: reduceMotion) { _, isEnabled in
                guard isEnabled else { return }
                reducedMotionWasEnabled = true
                pixelEntranceTask?.cancel()
                pixelEntranceTask = nil
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
            .scaleEffect(isInFinalThreeSeconds && !usesReducedMotion ? 0.97 : 1)
            .scaleEffect(isCardHovered && !usesReducedMotion ? 1.03 : 1)
            .animation(
                usesReducedMotion ? nil : .easeOut(duration: 0.3),
                value: isCardHovered
            )
            .rotation3DEffect(
                .degrees(usesReducedMotion ? 0 : tiltX),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.6
            )
            .rotation3DEffect(
                .degrees(usesReducedMotion ? 0 : tiltY),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.6
            )
            .animation(
                usesReducedMotion ? nil : .easeInOut(duration: 0.4),
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
                    usesReducedMotion ? nil : .spring(response: 0.4, dampingFraction: 0.55)
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
        AtmosphereBackground(
            palette: state.theme.atmosphere(isNightMode: state.isNightMode)
        )
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: EyeBreakDesign.Spacing.xs) {
            HStack(spacing: EyeBreakDesign.Spacing.xs) {
                animatedEye
                Text(state.isInformational
                    ? "EyeBreak"
                    : "Eye break · \(Int(state.duration)) sec")
                    .font(EyeBreakDesign.Typography.metadata)
                    .foregroundStyle(EyeBreakDesign.textSecondary)
            }

            HStack(alignment: .center, spacing: EyeBreakDesign.Spacing.md) {
                cardTitle
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                countdownRing
            }

            Text(state.displayedSubtitle)
                .font(EyeBreakDesign.Typography.metadata)
                .foregroundStyle(EyeBreakDesign.textSecondary)
                .lineLimit(state.cardSizeVariant == .compact ? 2 : 1)
                .minimumScaleFactor(0.9)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: state.displayedSubtitle)

            HStack(spacing: EyeBreakDesign.Spacing.sm) {
                if state.showsFocusExercise {
                    focusPhases
                }
                Spacer(minLength: 0)
                if state.currentStreak >= 3 {
                    streakIndicator
                }
            }
            .frame(height: 24)
        }
        .padding(.horizontal, HUDLayout.standardHorizontalContentPadding)
        .padding(.vertical, EyeBreakDesign.Spacing.lg)
    }

    private var cardTitle: some View {
        ZStack(alignment: .leading) {
            headline(state.message.title)
                .opacity(isCardHovered ? 0 : 1)
            headline(state.isHeld ? "Timer waiting" : "Still counting")
                .opacity(isCardHovered ? 1 : 0)
        }
        .frame(height: state.cardSizeVariant == .compact ? 80 : 48, alignment: .leading)
        .opacity(entranceTextIsVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isCardHovered)
        .animation(textEntranceAnimation(delay: 0.15), value: entranceTrigger)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.message.title)
    }

    private func headline(_ text: String) -> some View {
        Text(text.uppercased())
            .font(EyeBreakDesign.Typography.display)
            .tracking(EyeBreakDesign.Typography.displayTracking)
            .lineSpacing(-3)
            .foregroundStyle(EyeBreakDesign.textPrimary)
            .lineLimit(state.cardSizeVariant == .compact ? 2 : 1)
            .minimumScaleFactor(0.65)
    }

    private var focusPhases: some View {
        HStack(spacing: EyeBreakDesign.Spacing.xs) {
            ForEach(Array(FocusExercisePhase.allCases.enumerated()), id: \.offset) { _, phase in
                Text(phase == .near ? "Near" : "Far")
                    .font(EyeBreakDesign.Typography.metadata)
                    .foregroundStyle(state.focusExercisePhase == phase
                        ? EyeBreakDesign.textPrimary
                        : EyeBreakDesign.textSecondary)
                    .frame(width: 36, height: 24)
                    .background(GlowSelection(isActive: state.focusExercisePhase == phase))
                    .accessibilityLabel(phase.subtitle)
                    .accessibilityAddTraits(state.focusExercisePhase == phase ? .isSelected : [])
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state.focusExercisePhase)
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
        Text("Streak \(state.currentStreak) days")
            .font(EyeBreakDesign.Typography.metadata)
            .foregroundStyle(EyeBreakDesign.textSecondary)
            .monospacedDigit()
            .lineLimit(1)
            .accessibilityLabel("\(state.currentStreak) day streak")
    }

    var cardHeight: CGFloat {
        state.cardHeight
    }

    private var isInFinalThreeSeconds: Bool {
        state.remainingSeconds < 3
    }

    // Pixel entrances use this inexpensive static fill. The assembled card owns
    // the single animated atmosphere, rather than one live atmosphere per block.
    var driftingBackground: some View {
        let palette = state.theme.atmosphere(isNightMode: state.isNightMode)
        return LinearGradient(
            colors: [palette.colors.first?.opacity(palette.intensity * 0.45) ?? palette.base, palette.base],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .background(palette.base)
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
        if usesReducedMotion {
            eyeIcon
        } else if #available(macOS 14.0, *) {
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
        .font(.system(size: HUDLayout.eyeIconFontSize, weight: .light))
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(EyeBreakDesign.textSecondary)
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
        GlowRing(
            progress: state.progress,
            diameter: HUDLayout.standardCountdownDiameter,
            lineWidth: HUDLayout.countdownStrokeWidth
        ) {
            Text("\(state.displayedSeconds)")
                .font(.system(size: HUDLayout.countdownNumberFontSize, weight: .light))
                .monospacedDigit()
                .foregroundStyle(EyeBreakDesign.textPrimary)
                .contentTransition(usesReducedMotion ? .opacity : .numericText())
        }
        .opacity(state.isHeld ? 0.55 : (state.isPaused ? 0.7 : 1))
        .animation(.easeInOut(duration: 0.3), value: state.isHeld)
        .accessibilityLabel(
            state.isHeld
                ? "Countdown held, \(state.displayedSeconds) seconds remaining"
                : "\(state.displayedSeconds) seconds remaining"
        )
    }
}
