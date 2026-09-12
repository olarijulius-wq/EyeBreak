import Foundation
import SwiftUI

enum EntranceStyle: CaseIterable {
    case bubble
    case unfurl
    case swing
    case pour
    case pop
    case slide
    case pixels
    case blinds
    case clipwipe
    case doors
    case iris
    case shutter
    case staggerwipe
    case wipe

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
        case .pixels:
            return PixelTransition.maximumDuration
        case .blinds:
            return MaskTransitionTiming.blindsDuration
        case .clipwipe:
            return MaskTransitionTiming.clipwipeDuration
        case .doors:
            return MaskTransitionTiming.doorsDuration
        case .iris:
            return MaskTransitionTiming.irisDuration
        case .shutter:
            return MaskTransitionTiming.shutterDuration
        case .staggerwipe:
            return MaskTransitionTiming.staggerwipeDuration
        case .wipe:
            return MaskTransitionTiming.wipeDuration
        }
    }

    var restingOffsetY: CGFloat {
        8
    }

    var matchingExitStyle: ExitStyle? {
        switch self {
        case .blinds:
            return .blinds
        case .clipwipe:
            return .clipwipe
        case .doors:
            return .doors
        case .iris:
            return .iris
        case .shutter:
            return .shutter
        case .staggerwipe:
            return .staggerwipe
        case .wipe:
            return .wipe
        case .bubble, .unfurl, .swing, .pour, .pop, .slide, .pixels:
            return nil
        }
    }
}

enum ExitStyle: CaseIterable {
    case shrinkToNotch
    case fall
    case dissolve
    case pixels
    case blinds
    case clipwipe
    case doors
    case iris
    case shutter
    case staggerwipe
    case wipe

    var duration: TimeInterval {
        switch self {
        case .shrinkToNotch:
            return 0.28
        case .fall:
            return 0.50
        case .dissolve:
            return 0.42
        case .pixels:
            return PixelTransition.maximumDuration
        case .blinds:
            return MaskTransitionTiming.blindsDuration
        case .clipwipe:
            return MaskTransitionTiming.clipwipeDuration
        case .doors:
            return MaskTransitionTiming.doorsDuration
        case .iris:
            return MaskTransitionTiming.irisDuration
        case .shutter:
            return MaskTransitionTiming.shutterDuration
        case .staggerwipe:
            return MaskTransitionTiming.staggerwipeDuration
        case .wipe:
            return MaskTransitionTiming.wipeDuration
        }
    }
}

private struct AngledWipeMask: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clampedProgress = min(max(progress, 0), 1)

        guard clampedProgress > 0 else {
            return Path()
        }

        let angle = CGFloat(12 * Double.pi / 180)
        let slant = tan(angle) * rect.height
        let overscan: CGFloat = 2
        let sweepX = rect.minX
            + ((rect.width + slant + overscan) * clampedProgress)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: sweepX, y: rect.minY))
        path.addLine(
            to: CGPoint(x: sweepX - slant, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

private enum MaskTransitionTiming {
    static let blindsBarCount = 8
    static let blindsStagger: TimeInterval = 0.04
    static let blindsSpringResponse: TimeInterval = 0.4
    static let blindsSpringDampingFraction = 0.8
    static let blindsDuration = Spring(
        response: blindsSpringResponse,
        dampingRatio: blindsSpringDampingFraction
    ).settlingDuration + TimeInterval(blindsBarCount - 1) * blindsStagger

    static let clipwipeDuration: TimeInterval = 0.45

    static let doorsSpringResponse: TimeInterval = 0.45
    static let doorsSpringDampingFraction = 0.85
    static let doorsDuration = Spring(
        response: doorsSpringResponse,
        dampingRatio: doorsSpringDampingFraction
    ).settlingDuration

    static let irisDuration: TimeInterval = 0.5

    static let shutterSlatCount = 12
    static let shutterStagger: TimeInterval = 0.015
    static let shutterSpringResponse: TimeInterval = 0.35
    static let shutterSpringDampingFraction = 0.75
    static let shutterDuration = Spring(
        response: shutterSpringResponse,
        dampingRatio: shutterSpringDampingFraction
    ).settlingDuration
        + TimeInterval(shutterSlatCount - 1) * shutterStagger

    static let staggerwipeColumnCount = 6
    static let staggerwipeStagger: TimeInterval = 0.06
    static let staggerwipeSpringResponse: TimeInterval = 0.5
    static let staggerwipeSpringDampingFraction = 0.7
    static let staggerwipeDuration = Spring(
        response: staggerwipeSpringResponse,
        dampingRatio: staggerwipeSpringDampingFraction
    ).settlingDuration
        + TimeInterval(staggerwipeColumnCount - 1)
            * staggerwipeStagger

    static let wipeDuration: TimeInterval = 0.4
}

enum PixelTransition {
    static let blockSize: CGFloat = 20
    static let minimumFallDistance: CGFloat = 120
    static let maximumFallDistance: CGFloat = 400
    static let columnDelay: TimeInterval = 0.02
    static let maximumJitter: TimeInterval = 0.08
    static let springResponse: TimeInterval = 0.5
    static let springDampingFraction = 0.7
    static let springSettlingDuration = Spring(
        response: springResponse,
        dampingRatio: springDampingFraction
    ).settlingDuration
    static let opacityDuration: TimeInterval = 0.15
    static let contentDelay: TimeInterval = 0.5
    static let contentFadeDuration: TimeInterval = 0.3

    static var maximumDuration: TimeInterval {
        duration(columnCount: columnCount(for: HUDLayout.maximumCardWidth))
    }

    static func columnCount(for width: CGFloat) -> Int {
        max(1, Int((width / blockSize).rounded(.up)))
    }

    static func rowCount(for height: CGFloat) -> Int {
        max(1, Int((height / blockSize).rounded(.up)))
    }

    static func duration(columnCount: Int) -> TimeInterval {
        TimeInterval(max(0, columnCount - 1)) * columnDelay
            + maximumJitter
            + springSettlingDuration
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

struct ExitAnimationValues {
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var offsetY: CGFloat = 0
    var rotation: Double = 0
    var blurRadius: CGFloat = 0
    var opacity: Double = 1
}

enum MaskTransitionStyle {
    case blinds
    case clipwipe
    case doors
    case iris
    case shutter
    case staggerwipe
    case wipe
}

extension HUDView {
    func startPixelEntranceIfNeeded() {
        guard case .pixels = state.entranceStyle else { return }

        pixelEntranceTask?.cancel()
        pixelEntranceStarted = false
        pixelContentIsVisible = false
        isAssembled = false
        pixelExitStarted = false

        let assemblyDuration = PixelTransition.duration(
            columnCount: pixelColumnCount
        )

        pixelEntranceTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            pixelEntranceStarted = true

            do {
                try await Task.sleep(
                    nanoseconds: nanoseconds(
                        for: PixelTransition.contentDelay
                    )
                )
            } catch {
                return
            }

            withAnimation(
                .easeOut(duration: PixelTransition.contentFadeDuration)
            ) {
                pixelContentIsVisible = true
            }

            do {
                try await Task.sleep(
                    nanoseconds: nanoseconds(
                        for: assemblyDuration
                            - PixelTransition.contentDelay
                    )
                )
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            isAssembled = true
        }
    }

    private func nanoseconds(for duration: TimeInterval) -> UInt64 {
        UInt64(max(0, duration) * 1_000_000_000)
    }

    var animatedCard: some View {
        transitionCard
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
    private var transitionCard: some View {
        if usesPixelExit {
            pixelExitCard
        } else if let activeMaskStyle {
            maskTransitionCard(
                style: activeMaskStyle,
                isExiting: state.isDismissing
            )
        } else {
            entranceAnimatedCard
        }
    }

    private var usesPixelExit: Bool {
        guard state.isDismissing else { return false }
        guard case .pixels = state.exitStyle else { return false }
        return true
    }

    private var activeMaskStyle: MaskTransitionStyle? {
        maskExitStyle ?? maskEntranceStyle
    }

    private var maskExitStyle: MaskTransitionStyle? {
        guard state.isDismissing else { return nil }

        switch state.exitStyle {
        case .blinds:
            return .blinds
        case .clipwipe:
            return .clipwipe
        case .doors:
            return .doors
        case .iris:
            return .iris
        case .shutter:
            return .shutter
        case .staggerwipe:
            return .staggerwipe
        case .wipe:
            return .wipe
        case .shrinkToNotch, .fall, .dissolve, .pixels:
            return nil
        }
    }

    var maskEntranceStyle: MaskTransitionStyle? {
        switch state.entranceStyle {
        case .blinds:
            return .blinds
        case .clipwipe:
            return .clipwipe
        case .doors:
            return .doors
        case .iris:
            return .iris
        case .shutter:
            return .shutter
        case .staggerwipe:
            return .staggerwipe
        case .wipe:
            return .wipe
        case .bubble, .unfurl, .swing, .pour, .pop, .slide, .pixels:
            return nil
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
        case .pixels:
            pixelEntrance
        case .blinds:
            maskTransitionCard(style: .blinds, isExiting: false)
        case .clipwipe:
            maskTransitionCard(style: .clipwipe, isExiting: false)
        case .doors:
            maskTransitionCard(style: .doors, isExiting: false)
        case .iris:
            maskTransitionCard(style: .iris, isExiting: false)
        case .shutter:
            maskTransitionCard(style: .shutter, isExiting: false)
        case .staggerwipe:
            maskTransitionCard(style: .staggerwipe, isExiting: false)
        case .wipe:
            maskTransitionCard(style: .wipe, isExiting: false)
        }
    }

    private func maskTransitionCard(
        style: MaskTransitionStyle,
        isExiting: Bool
    ) -> some View {
        let isRevealed = isExiting
            ? !maskExitStarted
            : entranceTrigger > 0

        return shapedCard
            .mask {
                transitionMask(
                    style: style,
                    isRevealed: isRevealed,
                    isExiting: isExiting
                )
            }
            .offset(y: state.entranceStyle.restingOffsetY)
    }

    @ViewBuilder
    private func transitionMask(
        style: MaskTransitionStyle,
        isRevealed: Bool,
        isExiting: Bool
    ) -> some View {
        switch style {
        case .blinds:
            blindsMask(
                isRevealed: isRevealed,
                isExiting: isExiting
            )
        case .clipwipe:
            clipwipeMask(
                isRevealed: isRevealed,
                isExiting: isExiting
            )
        case .doors:
            doorsMask(isRevealed: isRevealed)
        case .iris:
            irisMask(
                isRevealed: isRevealed,
                isExiting: isExiting
            )
        case .shutter:
            shutterMask(
                isRevealed: isRevealed,
                isExiting: isExiting
            )
        case .staggerwipe:
            staggerwipeMask(
                isRevealed: isRevealed,
                isExiting: isExiting
            )
        case .wipe:
            wipeMask(isRevealed: isRevealed)
        }
    }

    private func blindsMask(
        isRevealed: Bool,
        isExiting: Bool
    ) -> some View {
        VStack(spacing: -1) {
            ForEach(
                0..<MaskTransitionTiming.blindsBarCount,
                id: \.self
            ) { index in
                Rectangle()
                    .fill(.white)
                    .frame(
                        height: (
                            cardHeight + CGFloat(
                                MaskTransitionTiming.blindsBarCount - 1
                            )
                        ) / CGFloat(MaskTransitionTiming.blindsBarCount)
                    )
                    .scaleEffect(
                        x: 1,
                        y: isRevealed ? 1 : 0,
                        anchor: .center
                    )
                    .animation(
                        .spring(
                            response: MaskTransitionTiming
                                .blindsSpringResponse,
                            dampingFraction: MaskTransitionTiming
                                .blindsSpringDampingFraction
                        )
                        .delay(
                            maskStaggerDelay(
                                index: index,
                                count: MaskTransitionTiming.blindsBarCount,
                                stagger: MaskTransitionTiming.blindsStagger,
                                isExiting: isExiting
                            )
                        ),
                        value: isRevealed
                    )
            }
        }
        .frame(
            width: state.cardSize.width,
            height: cardHeight
        )
    }

    private func clipwipeMask(
        isRevealed: Bool,
        isExiting: Bool
    ) -> some View {
        let animation: Animation = isExiting
            ? .easeIn(duration: MaskTransitionTiming.clipwipeDuration)
            : .easeOut(duration: MaskTransitionTiming.clipwipeDuration)

        return AngledWipeMask(progress: isRevealed ? 1 : 0)
            .fill(.white)
            .frame(
                width: state.cardSize.width,
                height: cardHeight
            )
            .animation(animation, value: isRevealed)
    }

    private func doorsMask(isRevealed: Bool) -> some View {
        HStack(spacing: -1) {
            Rectangle()
                .fill(.white)
                .scaleEffect(
                    x: isRevealed ? 1 : 0,
                    y: 1,
                    anchor: .trailing
                )

            Rectangle()
                .fill(.white)
                .scaleEffect(
                    x: isRevealed ? 1 : 0,
                    y: 1,
                    anchor: .leading
                )
        }
        .frame(
            width: state.cardSize.width,
            height: cardHeight
        )
        .animation(
            .spring(
                response: MaskTransitionTiming.doorsSpringResponse,
                dampingFraction: MaskTransitionTiming
                    .doorsSpringDampingFraction
            ),
            value: isRevealed
        )
    }

    private func irisMask(
        isRevealed: Bool,
        isExiting: Bool
    ) -> some View {
        let diameter = sqrt(
            (state.cardSize.width * state.cardSize.width)
                + (cardHeight * cardHeight)
        ) + 2
        let animation: Animation = isExiting
            ? .easeIn(duration: MaskTransitionTiming.irisDuration)
            : .easeOut(duration: MaskTransitionTiming.irisDuration)

        return Circle()
            .fill(.white)
            .frame(width: diameter, height: diameter)
            .scaleEffect(isRevealed ? 1 : 0, anchor: .center)
            .frame(
                width: state.cardSize.width,
                height: cardHeight
            )
            .animation(animation, value: isRevealed)
    }

    private func shutterMask(
        isRevealed: Bool,
        isExiting: Bool
    ) -> some View {
        HStack(spacing: -1) {
            ForEach(
                0..<MaskTransitionTiming.shutterSlatCount,
                id: \.self
            ) { index in
                Rectangle()
                    .fill(.white)
                    .frame(
                        width: (
                            state.cardSize.width + CGFloat(
                                MaskTransitionTiming.shutterSlatCount - 1
                            )
                        ) / CGFloat(MaskTransitionTiming.shutterSlatCount)
                    )
                    .scaleEffect(
                        x: isRevealed ? 1 : 0,
                        y: 1,
                        anchor: .center
                    )
                    .animation(
                        .spring(
                            response: MaskTransitionTiming
                                .shutterSpringResponse,
                            dampingFraction: MaskTransitionTiming
                                .shutterSpringDampingFraction
                        )
                        .delay(
                            maskStaggerDelay(
                                index: index,
                                count: MaskTransitionTiming
                                    .shutterSlatCount,
                                stagger: MaskTransitionTiming
                                    .shutterStagger,
                                isExiting: isExiting
                            )
                        ),
                        value: isRevealed
                    )
            }
        }
        .frame(
            width: state.cardSize.width,
            height: cardHeight
        )
    }

    private func staggerwipeMask(
        isRevealed: Bool,
        isExiting: Bool
    ) -> some View {
        HStack(spacing: -1) {
            ForEach(
                0..<MaskTransitionTiming.staggerwipeColumnCount,
                id: \.self
            ) { index in
                Rectangle()
                    .fill(.white)
                    .frame(
                        width: (
                            state.cardSize.width + CGFloat(
                                MaskTransitionTiming
                                    .staggerwipeColumnCount - 1
                            )
                        ) / CGFloat(
                                MaskTransitionTiming
                                    .staggerwipeColumnCount
                            ),
                        height: cardHeight
                    )
                    .offset(y: isRevealed ? 0 : -cardHeight)
                    .animation(
                        .spring(
                            response: MaskTransitionTiming
                                .staggerwipeSpringResponse,
                            dampingFraction: MaskTransitionTiming
                                .staggerwipeSpringDampingFraction
                        )
                        .delay(
                            maskStaggerDelay(
                                index: index,
                                count: MaskTransitionTiming
                                    .staggerwipeColumnCount,
                                stagger: MaskTransitionTiming
                                    .staggerwipeStagger,
                                isExiting: isExiting
                            )
                        ),
                        value: isRevealed
                    )
            }
        }
        .frame(
            width: state.cardSize.width,
            height: cardHeight
        )
    }

    private func wipeMask(isRevealed: Bool) -> some View {
        Rectangle()
            .fill(.white)
            .frame(
                width: isRevealed ? state.cardSize.width : 0,
                height: cardHeight
            )
            .frame(
                width: state.cardSize.width,
                height: cardHeight,
                alignment: .leading
            )
            .animation(
                .easeInOut(duration: MaskTransitionTiming.wipeDuration),
                value: isRevealed
            )
    }

    private func maskStaggerDelay(
        index: Int,
        count: Int,
        stagger: TimeInterval,
        isExiting: Bool
    ) -> TimeInterval {
        let staggerIndex = isExiting ? count - 1 - index : index
        return TimeInterval(staggerIndex) * stagger
    }

    private var shapedCard: some View {
        let silhouette = cardSilhouette
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

    @ViewBuilder
    private var pixelEntrance: some View {
        if isAssembled {
            shapedCard
                .offset(y: state.entranceStyle.restingOffsetY)
        } else {
            pixelTransitionCard(isExiting: false)
        }
    }

    private var pixelExitCard: some View {
        pixelTransitionCard(isExiting: true)
    }

    private func pixelTransitionCard(isExiting: Bool) -> some View {
        let silhouette = cardSilhouette
        let contentOpacity = isExiting
            ? (pixelExitStarted ? 0.0 : 1.0)
            : (pixelContentIsVisible ? 1.0 : 0.0)
        let contentAnimation: Animation = isExiting
            ? .easeIn(duration: PixelTransition.opacityDuration)
            : .easeOut(duration: PixelTransition.contentFadeDuration)

        return ZStack {
            pixelGrid(isExiting: isExiting)

            cardForeground
                .clipShape(silhouette)
                .opacity(contentOpacity)
                .animation(contentAnimation, value: contentOpacity)
        }
        .overlay {
            silhouette
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .opacity(contentOpacity)
                .animation(contentAnimation, value: contentOpacity)
        }
        .frame(
            width: state.cardSize.width,
            height: cardHeight
        )
        .offset(y: state.entranceStyle.restingOffsetY)
    }

    private func pixelGrid(isExiting: Bool) -> some View {
        let blockCount = pixelColumnCount * pixelRowCount

        return ZStack(alignment: .topLeading) {
            ForEach(0..<blockCount, id: \.self) { index in
                pixelBlock(index: index, isExiting: isExiting)
            }
        }
        .frame(
            width: state.cardSize.width,
            height: cardHeight,
            alignment: .topLeading
        )
    }

    private func pixelBlock(
        index: Int,
        isExiting: Bool
    ) -> some View {
        let column = index % pixelColumnCount
        let row = index / pixelColumnCount
        let isAnimating = isExiting
            ? pixelExitStarted
            : pixelEntranceStarted
        let distance = pixelFallDistance(for: index)
        let delay = pixelDelay(
            column: column,
            index: index,
            isExiting: isExiting
        )
        let offsetY: CGFloat
        let opacity: Double

        if isExiting {
            offsetY = isAnimating ? distance : 0
            opacity = isAnimating ? 0 : 1
        } else {
            offsetY = isAnimating ? 0 : -distance
            opacity = isAnimating ? 1 : 0
        }

        let fallingBlock = driftingBackground
            .frame(
                width: state.cardSize.width,
                height: cardHeight
            )
            .clipShape(cardSilhouette)
            .mask(alignment: .topLeading) {
                Rectangle()
                    .frame(
                        width: PixelTransition.blockSize,
                        height: PixelTransition.blockSize
                    )
                    .offset(
                        x: CGFloat(column) * PixelTransition.blockSize,
                        y: CGFloat(row) * PixelTransition.blockSize
                    )
            }
            .offset(y: offsetY)
            .animation(
                .spring(
                    response: PixelTransition.springResponse,
                    dampingFraction: PixelTransition.springDampingFraction
                )
                .delay(delay),
                value: isAnimating
            )

        return fallingBlock
            .opacity(opacity)
            .animation(
                .linear(duration: PixelTransition.opacityDuration)
                    .delay(delay),
                value: isAnimating
            )
    }

    private var pixelColumnCount: Int {
        PixelTransition.columnCount(for: state.cardSize.width)
    }

    private var pixelRowCount: Int {
        PixelTransition.rowCount(for: cardHeight)
    }

    private func pixelDelay(
        column: Int,
        index: Int,
        isExiting: Bool
    ) -> TimeInterval {
        let cascadeColumn = isExiting
            ? pixelColumnCount - 1 - column
            : column
        let jitter = pixelRandomUnit(
            index: index,
            salt: 0xA24B_AED4_963E_E407
        ) * PixelTransition.maximumJitter

        return TimeInterval(cascadeColumn) * PixelTransition.columnDelay
            + jitter
    }

    private func pixelFallDistance(for index: Int) -> CGFloat {
        let unitValue = pixelRandomUnit(
            index: index,
            salt: 0x9FB2_1C65_1E98_DF25
        )
        return PixelTransition.minimumFallDistance
            + CGFloat(unitValue)
                * (
                    PixelTransition.maximumFallDistance
                        - PixelTransition.minimumFallDistance
                )
    }

    private func pixelRandomUnit(
        index: Int,
        salt: UInt64
    ) -> Double {
        var value = pixelAnimationSeed
            &+ UInt64(index) &* 0x9E37_79B9_7F4A_7C15
            &+ salt
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31

        return Double(value >> 11) / 9_007_199_254_740_992
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
        pixelEntranceTask?.cancel()
        pixelEntranceTask = nil

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

        case .pixels:
            pixelExitStarted = false

            DispatchQueue.main.async {
                guard state.isDismissing else { return }
                pixelExitStarted = true
            }

        case .blinds, .clipwipe, .doors, .iris, .shutter,
             .staggerwipe, .wipe:
            maskExitStarted = false

            DispatchQueue.main.async {
                guard state.isDismissing else { return }
                maskExitStarted = true
            }
        }
    }
}
