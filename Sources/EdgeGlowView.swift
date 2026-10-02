import AppKit
import QuartzCore
import SwiftUI

// Geometry is expressed in the panel's local, bottom-left coordinate system.
// NSScreen has public notch geometry but no public physical corner-radius API.
struct EdgeGlowGeometry {
    let size: CGSize
    let cornerRadius: CGFloat
    let notch: CGRect?

    init(size: CGSize, cornerRadius: CGFloat, notch: CGRect?) {
        self.size = size
        self.cornerRadius = cornerRadius
        self.notch = notch
    }

    init(size: CGSize, screen: NSScreen?) {
        self.size = size
        guard let screen else {
            cornerRadius = min(12, min(size.width, size.height) / 8)
            notch = nil
            return
        }

        let inset = screen.safeAreaInsets.top
        let screenWidth = screen.frame.width
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           inset > 0, screenWidth > 0, left.width > 0, right.width > 0,
           left.width + right.width < screenWidth {
            let xScale = size.width / screenWidth
            let yScale = size.height / max(1, screen.frame.height)
            let depth = inset * yScale
            notch = CGRect(
                x: left.width * xScale,
                y: size.height - depth,
                width: (screenWidth - left.width - right.width) * xScale,
                height: depth
            )
            // A conservative visual approximation, without private display APIs.
            cornerRadius = 16 * min(xScale, yScale)
        } else {
            notch = nil
            cornerRadius = 0
        }
    }

    var contour: CGPath {
        let path = CGMutablePath()
        let w = size.width
        let h = size.height
        let r = min(cornerRadius, min(w, h) / 2)
        path.move(to: CGPoint(x: r, y: 0))
        path.addLine(to: CGPoint(x: w - r, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: r), control: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h - r))
        path.addQuadCurve(to: CGPoint(x: w - r, y: h), control: CGPoint(x: w, y: h))
        if let notch {
            let n = min(6, notch.height / 3)
            path.addLine(to: CGPoint(x: notch.maxX + n, y: h))
            path.addQuadCurve(
                to: CGPoint(x: notch.maxX, y: h - n),
                control: CGPoint(x: notch.maxX, y: h)
            )
            path.addLine(to: CGPoint(x: notch.maxX, y: notch.minY + n))
            path.addQuadCurve(
                to: CGPoint(x: notch.maxX - n, y: notch.minY),
                control: CGPoint(x: notch.maxX, y: notch.minY)
            )
            path.addLine(to: CGPoint(x: notch.minX + n, y: notch.minY))
            path.addQuadCurve(
                to: CGPoint(x: notch.minX, y: notch.minY + n),
                control: CGPoint(x: notch.minX, y: notch.minY)
            )
            path.addLine(to: CGPoint(x: notch.minX, y: h - n))
            path.addQuadCurve(
                to: CGPoint(x: notch.minX - n, y: h),
                control: CGPoint(x: notch.minX, y: h)
            )
        }
        path.addLine(to: CGPoint(x: r, y: h))
        path.addQuadCurve(to: CGPoint(x: 0, y: h - r), control: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: r))
        path.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero)
        path.closeSubpath()
        return path
    }

    func strips(depth: CGFloat, scale: CGFloat) -> [CGRect] {
        // One extra physical pixel preserves antialiasing at the feather's end.
        // Whole-point joins are also pixel aligned when a preview is captured
        // at 1x after its textures were prepared for a Retina host.
        let side = ceil(depth + 1 / scale)
        let top = ceil(depth + (notch?.height ?? 0) + 1 / scale)
        let middleHeight = max(0, size.height - top - side)
        return [
            CGRect(x: 0, y: size.height - top, width: size.width, height: top),
            CGRect(x: 0, y: 0, width: size.width, height: side),
            CGRect(x: 0, y: side, width: side, height: middleHeight),
            CGRect(x: size.width - side, y: side, width: side, height: middleHeight)
        ]
    }
}

/// Layer-hosting view: only narrow, immutable edge textures contain pixels.
/// Countdown, breathing, phase changes and presentation animate opacity in CA.
final class EdgeGlowView: NSView {
    private let rootLayer = CALayer()
    private let breathingLayer = CALayer()
    private let progressLayer = CALayer()
    private let wideLayer = CALayer()
    private let nearLayer = CALayer()
    private var theme: Theme = .ember
    private var isNightMode = false
    private var display: NSScreen?
    private var reduceMotion = false
    private var isHeld = false
    private var currentPhase: FocusExercisePhase?
    private var breathingDuration: TimeInterval?
    private var renderedKey: String?
    private var lastVisualState: VisualState?

    private struct VisualState: Equatable {
        let progressStep: Int
        let phase: FocusExercisePhase?
        let isHeld: Bool
        let reduceMotion: Bool
        let isNightMode: Bool
    }

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer = rootLayer
        wantsLayer = true
        // Each phase's strips are disjoint. Applying alpha to their children
        // avoids flattening a transparent full-display container every frame.
        for container in [rootLayer, breathingLayer, progressLayer, wideLayer, nearLayer] {
            container.allowsGroupOpacity = false
            container.shouldRasterize = false
        }
        rootLayer.opacity = 0
        breathingLayer.opacity = 0.82
        rootLayer.addSublayer(breathingLayer)
        breathingLayer.addSublayer(progressLayer)
        progressLayer.addSublayer(wideLayer)
        progressLayer.addSublayer(nearLayer)
        nearLayer.opacity = 0
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(theme: Theme, isNightMode: Bool, screen: NSScreen?) {
        self.theme = theme
        self.isNightMode = isNightMode
        display = screen
        regenerateIfNeeded()
        configureBreathing()
    }

    func update(progress: Double, phase: FocusExercisePhase?, isHeld: Bool, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        self.isHeld = isHeld
        // A hold temporarily hides the state model's phase; retain its visual
        // character until the same countdown resumes.
        if !isHeld || phase != nil { currentPhase = phase }
        // The controller's existing timer runs at 30 Hz. Forty visual steps
        // across the break keep fades smooth without restarting them per tick.
        let progressStep = Int((min(max(progress, 0), 1) * 40).rounded())
        let visualState = VisualState(progressStep: progressStep, phase: currentPhase, isHeld: isHeld, reduceMotion: reduceMotion, isNightMode: isNightMode)
        guard lastVisualState != visualState else { return }
        lastVisualState = visualState
        let near = currentPhase == .near
        let fadeDuration: TimeInterval = reduceMotion ? 0.2 : 0.8
        setOpacity(near ? 0 : 1, on: wideLayer, duration: fadeDuration)
        setOpacity(near ? 1 : 0, on: nearLayer, duration: fadeDuration)
        let completion = Double(progressStep) / 40
        // Softening is continuous, but the center is always completely clear.
        let nightStrength = isNightMode ? 0.48 : 1.0
        setOpacity(Float((0.24 + 0.76 * completion) * nightStrength), on: progressLayer, duration: 0.35)
        configureBreathing()
    }

    func fadeIn() {
        setOpacity(1, on: rootLayer, duration: reduceMotion ? 0.35 : 1)
    }

    func fadeOut(duration: TimeInterval) {
        setOpacity(0, on: rootLayer, duration: duration)
    }

    override func layout() {
        super.layout()
        regenerateIfNeeded()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        regenerateIfNeeded()
    }

    private func configureBreathing() {
        if reduceMotion {
            breathingDuration = nil
            breathingLayer.removeAnimation(forKey: "breath")
            setOpacity(0.82, on: breathingLayer, duration: 0.2)
            return
        }
        let duration: TimeInterval = isHeld ? (isNightMode ? 12 : 9) : (isNightMode ? 7 : 4.5)
        guard breathingDuration != duration else { return }
        let current = breathingLayer.presentation()?.opacity ?? breathingLayer.opacity
        breathingDuration = duration
        breathingLayer.removeAnimation(forKey: "opacityFade")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        breathingLayer.opacity = 1
        CATransaction.commit()
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [max(0.6, min(1, current)), 0.6, 1, max(0.6, min(1, current))]
        animation.keyTimes = [0, 0.25, 0.75, 1]
        animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 3)
        animation.duration = duration
        animation.repeatCount = .infinity
        breathingLayer.add(animation, forKey: "breath")
    }

    private func setOpacity(_ opacity: Float, on target: CALayer, duration: TimeInterval) {
        guard abs(target.opacity - opacity) > 0.0001 else { return }
        let previous = target.presentation()?.opacity ?? target.opacity
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        target.opacity = opacity
        CATransaction.commit()
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = previous
        fade.toValue = opacity
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        target.add(fade, forKey: "opacityFade")
    }

    private func regenerateIfNeeded() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let scale = max(1, window?.backingScaleFactor ?? display?.backingScaleFactor ?? 2)
        let geometry = EdgeGlowGeometry(size: bounds.size, screen: display)
        let key = "\(bounds.size)-\(scale)-\(theme.rawValue)-\(geometry.cornerRadius)-\(String(describing: geometry.notch))"
        guard renderedKey != key else { return }
        renderedKey = key
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for container in [breathingLayer, progressLayer, wideLayer, nearLayer] {
            container.frame = CGRect(origin: .zero, size: bounds.size)
        }
        // The small settings preview scales depth down to preserve its center.
        let maximumDepth = min(bounds.width, bounds.height) * 0.24
        installStrips(on: wideLayer, geometry: geometry, depth: min(72, maximumDepth), strength: 0.72, scale: scale)
        installStrips(on: nearLayer, geometry: geometry, depth: min(44, maximumDepth * 0.62), strength: 0.96, scale: scale)
        CATransaction.commit()
    }

    private func installStrips(on container: CALayer, geometry: EdgeGlowGeometry, depth: CGFloat, strength: CGFloat, scale: CGFloat) {
        container.sublayers?.forEach { $0.removeFromSuperlayer() }
        let colors = theme.atmosphere.colors.map { color in
            (NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)).cgColor
        }
        guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil) else { return }
        for rect in geometry.strips(depth: depth, scale: scale) where rect.width > 0 && rect.height > 0 {
            guard let image = edgeImage(rect: rect, geometry: geometry, depth: depth, strength: strength, scale: scale, gradient: gradient) else { continue }
            let strip = CALayer()
            strip.frame = rect
            strip.contents = image
            strip.contentsScale = scale
            strip.contentsGravity = .resize
            container.addSublayer(strip)
        }
    }

    private func edgeImage(rect: CGRect, geometry: EdgeGlowGeometry, depth: CGFloat, strength: CGFloat, scale: CGFloat, gradient: CGGradient) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: Int(ceil(rect.width * scale)), height: Int(ceil(rect.height * scale)),
                bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -rect.minX, y: -rect.minY)
        let contour = geometry.contour
        context.addPath(contour)
        context.clip()
        context.setLineJoin(.round)
        // Nested translucent strokes sample a quadratic feather once, at build
        // time for these textures. No live shadows, filters or full-screen mask.
        let samples = 64
        var previousAlpha: CGFloat = 0
        for index in 0..<samples {
            let fraction = CGFloat(index + 1) / CGFloat(samples)
            let desiredAlpha = strength * fraction * fraction
            let increment = (desiredAlpha - previousAlpha) / (1 - previousAlpha)
            context.setStrokeColor(CGColor(gray: 1, alpha: increment))
            context.setLineWidth(2 * depth * (1 - CGFloat(index) / CGFloat(samples)))
            context.addPath(contour)
            context.strokePath()
            previousAlpha = desiredAlpha
        }
        context.setBlendMode(.sourceIn)
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: geometry.size.height),
            end: CGPoint(x: geometry.size.width, y: 0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        return context.makeImage()
    }
}

private struct EdgeGlowPreviewSurface: NSViewRepresentable {
    let theme: Theme
    let isNightMode: Bool
    let focusExerciseEnabled: Bool
    let reduceMotion: Bool

    func makeNSView(context: Context) -> EdgeGlowView {
        let view = EdgeGlowView(frame: .zero)
        updateNSView(view, context: context)
        view.fadeIn()
        return view
    }

    func updateNSView(_ nsView: EdgeGlowView, context: Context) {
        nsView.configure(theme: isNightMode ? .mono : theme, isNightMode: isNightMode, screen: nil)
        nsView.update(progress: 0.9, phase: focusExerciseEnabled ? .initialFar : nil, isHeld: false, reduceMotion: reduceMotion)
    }
}

struct EdgeGlowPreview: View {
    let theme: Theme
    let isNightMode: Bool
    let focusExerciseEnabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            EyeBreakDesign.base
            EdgeGlowPreviewSurface(
                theme: theme,
                isNightMode: isNightMode,
                focusExerciseEnabled: focusExerciseEnabled,
                reduceMotion: reduceMotion
            )
            VStack(spacing: EyeBreakDesign.Spacing.xxs) {
                MicroLabel(focusExerciseEnabled ? "Eye break · Far focus" : "Eye break")
                Text("LOOK FAR AWAY · 18")
                    .font(EyeBreakDesign.Typography.metadata)
                    .tracking(EyeBreakDesign.Typography.metadataTracking)
                    .foregroundStyle(EyeBreakDesign.textPrimary)
            }
            .padding(.top, EyeBreakDesign.Spacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: EyeBreakDesign.Radius.control))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Edge glow preview, look far away, 18 seconds remaining")
    }
}
