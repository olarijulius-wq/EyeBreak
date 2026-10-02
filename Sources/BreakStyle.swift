enum BreakStyle: String, CaseIterable {
    case edgeGlow
    case card

    static let defaultStyle: BreakStyle = .edgeGlow

    var displayName: String {
        switch self {
        case .edgeGlow: return "Edge glow"
        case .card: return "Card"
        }
    }

    static func normalizedRawValue(_ storedValue: String?) -> String {
        storedValue.flatMap(Self.init(rawValue:))?.rawValue
            ?? defaultStyle.rawValue
    }
}
