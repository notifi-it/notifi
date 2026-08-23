import MarkdownUI
import SwiftUI

struct MarkdownText: View {
    let source: String
    let allowAnyScheme: Bool
    var allowsRemoteImages: Bool = false
    var critical: Bool = false

    var body: some View {
        Group {
            if allowsRemoteImages {
                markdown
            } else {
                markdown
                    .markdownImageProvider(BlockedImageProvider())
                    .markdownInlineImageProvider(BlockedInlineImageProvider())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .environment(\.openURL, OpenURLAction { url in
            LinkPolicy.allows(url, anyScheme: allowAnyScheme) ? .systemAction : .discarded
        })
    }

    private var markdown: some View {
        Markdown(source).markdownTheme(.geist(critical: critical))
    }
}

private struct RemoteImageBlocked: Error {}

private struct BlockedImageProvider: ImageProvider {
    func makeImage(url: URL?) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "photo")
                .font(.system(size: 12, weight: .medium))
            Text(Copy.Message.imageHidden)
                .font(.inco(.footnote))
        }
        .foregroundStyle(Theme.dim)
        .padding(.vertical, 10)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.chip, lineWidth: 1))
    }
}

private struct BlockedInlineImageProvider: InlineImageProvider {
    func image(with url: URL, label: String) async throws -> Image {
        throw RemoteImageBlocked()
    }
}

extension MarkdownUI.Theme {
    @MainActor
    static func geist(critical: Bool = false) -> MarkdownUI.Theme {
        MarkdownUI.Theme()
        .text {
            FontFamily(.custom("Karla"))
            FontSize(15)
            ForegroundColor(Theme.muted)
        }
        .strong {
            FontWeight(.semibold)
            ForegroundColor(critical ? Theme.brandDim : Theme.fg)
        }
        .code {
            FontFamily(.custom("Recursive Mono"))
            FontSize(15)
            ForegroundColor(Theme.fg)
        }
        .link {
            ForegroundColor(Theme.fg)
            UnderlineStyle(.single)
        }
        .heading1 { bandHeading($0) }
        .heading2 { bandHeading($0) }
        .heading3 { bandHeading($0) }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.2))
                .markdownMargin(top: .em(0.8))
        }
        .blockquote { configuration in
            HStack(alignment: .top, spacing: 10) {
                Rectangle().fill(Theme.controlBorder).frame(width: 2)
                configuration.label
                    .markdownTextStyle { ForegroundColor(Theme.dim) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .markdownMargin(top: .em(0.8))
        }
        .codeBlock { configuration in
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .relativeLineSpacing(.em(0.2))
                    .markdownTextStyle {
                        FontFamily(.custom("Recursive Mono"))
                        FontSize(13)
                        ForegroundColor(Theme.fg)
                    }
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .overlay(alignment: .trailing) {
                LinearGradient(colors: [Theme.surface.opacity(0), Theme.surface],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 32)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.chip, lineWidth: 1))
            .markdownMargin(top: .em(0.8), bottom: .em(0.8))
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.3))
        }
        .thematicBreak {
            Hairline()
                .markdownMargin(top: .em(1), bottom: .em(1))
        }
    }
    @MainActor
    private static func bandHeading(_ configuration: BlockConfiguration) -> some View {
        HStack(spacing: 10) {
            configuration.label
                .textCase(.uppercase)
                .tracking(1.4)
                .markdownTextStyle {
                    FontFamily(.custom("Recursive Mono"))
                    FontSize(11)
                    FontWeight(.semibold)
                    ForegroundColor(Theme.fg)
                }
            Hairline()
        }
        .markdownMargin(top: 20, bottom: 6)
    }
}
