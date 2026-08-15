import SwiftUI

extension Font {
    static func inco(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom("Recursive Mono", size: incoSize(style), relativeTo: style).weight(incoWeight(weight))
    }

    static func inco(size: CGFloat, weight: Font.Weight = .regular,
                     relativeTo style: Font.TextStyle = .caption) -> Font {
        .custom("Recursive Mono", size: size, relativeTo: style).weight(incoWeight(weight))
    }

    /// Recursive Mono draws lighter than Inconsolata did at the same nominal
    /// weight, so every request is bumped a step and bold two. Call sites still
    /// ask in Inconsolata-era terms.
    private static func incoWeight(_ weight: Font.Weight) -> Font.Weight {
        switch weight {
        case .regular: .medium
        case .medium: .semibold
        case .semibold: .bold
        case .bold: .black
        default: weight
        }
    }

    static func karla(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom("Karla", size: incoSize(style), relativeTo: style).weight(weight)
    }

    private static func incoSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }
}
