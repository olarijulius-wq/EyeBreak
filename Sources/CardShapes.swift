import SwiftUI

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
                HeightScaledRoundedRectangle(radiusRatio: 30 / 96)
            )
        case .pill:
            return AnyShape(HalfHeightRoundedRectangle())
        case .blob:
            return AnyShape(
                HeightScaledAsymmetricRoundedForm(
                    topLeftRadiusRatio: 44 / 96,
                    topRightRadiusRatio: 18 / 96,
                    bottomRightRadiusRatio: 38 / 96,
                    bottomLeftRadiusRatio: 24 / 96
                )
            )
        case .tag:
            return AnyShape(
                HeightScaledAsymmetricRoundedForm(
                    topLeftRadiusRatio: 30 / 96,
                    topRightRadiusRatio: 30 / 96,
                    bottomRightRadiusRatio: 30 / 96,
                    bottomLeftRadiusRatio: 0
                )
            )
        case .leaf:
            return AnyShape(LeafShape())
        }
    }
}

private struct HeightScaledRoundedRectangle: Shape {
    let radiusRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(
            cornerRadius: rect.height * radiusRatio,
            style: .continuous
        )
        .path(in: rect)
    }
}

private struct HeightScaledAsymmetricRoundedForm: Shape {
    let topLeftRadiusRatio: CGFloat
    let topRightRadiusRatio: CGFloat
    let bottomRightRadiusRatio: CGFloat
    let bottomLeftRadiusRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        AsymmetricRoundedForm(
            topLeftRadius: rect.height * topLeftRadiusRatio,
            topRightRadius: rect.height * topRightRadiusRatio,
            bottomRightRadius: rect.height * bottomRightRadiusRatio,
            bottomLeftRadius: rect.height * bottomLeftRadiusRatio
        )
        .path(in: rect)
    }
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
