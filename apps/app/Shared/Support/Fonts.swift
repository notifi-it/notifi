import SwiftUI

extension Font {
    static func inco(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom("Inconsolata", size: incoSize(style), relativeTo: style).weight(weight)
    }

    static func inco(size: CGFloat, weight: Font.Weight = .regular,
                     relativeTo style: Font.TextStyle = .caption) -> Font {
        .custom("Inconsolata", size: size, relativeTo: style).weight(weight)
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
