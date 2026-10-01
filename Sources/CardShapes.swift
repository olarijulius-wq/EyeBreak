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
            return AnyShape(HeightScaledRoundedRectangle(radiusRatio: 0.28))
        case .squircle:
            return AnyShape(
                HeightScaledRoundedRectangle(radiusRatio: 0.18)
            )
        case .pill:
            return AnyShape(SoftPillShape())
        case .blob:
            return AnyShape(
                HeightScaledAsymmetricRoundedForm(
                    topLeftRadiusRatio: 0.26,
                    topRightRadiusRatio: 0.18,
                    bottomRightRadiusRatio: 0.24,
                    bottomLeftRadiusRatio: 0.20
                )
            )
        case .tag:
            return AnyShape(
                HeightScaledAsymmetricRoundedForm(
                    topLeftRadiusRatio: 0.22,
                    topRightRadiusRatio: 0.22,
                    bottomRightRadiusRatio: 0.22,
                    bottomLeftRadiusRatio: 0.14
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

private struct SoftPillShape: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(
            cornerRadius: rect.height * 0.32,
            style: .continuous
        )
        .path(in: rect)
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        let fullRadius = min(rect.width, rect.height) * 0.32
        let softTipRadius = min(rect.width, rect.height) * 0.14

        return AsymmetricRoundedForm(
            topLeftRadius: softTipRadius,
            topRightRadius: fullRadius,
            bottomRightRadius: softTipRadius,
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
        return UnevenRoundedRectangle(
            topLeadingRadius: radii.topLeft,
            bottomLeadingRadius: radii.bottomLeft,
            bottomTrailingRadius: radii.bottomRight,
            topTrailingRadius: radii.topRight,
            style: .continuous
        )
        .path(in: rect)
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
