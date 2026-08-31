import SwiftUI
import Textual

struct MarkdownText: View {
    let source: String
    let allowAnyScheme: Bool
    var allowsRemoteImages: Bool = false

    var body: some View {
        Group {
            if allowsRemoteImages {
                markdown
            } else {
                markdown
                    .textual.imageAttachmentLoader(BlockedImageLoader())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textual.textSelection(.enabled)
        .environment(\.openURL, OpenURLAction { url in
            LinkPolicy.allows(url, anyScheme: allowAnyScheme) ? .systemAction : .discarded
        })
    }

    private var markdown: some View {
        StructuredText(markdown: source)
            .font(.custom("Karla", size: 15))
            .foregroundStyle(Theme.muted)
            .textual.structuredTextStyle(GeistStructuredStyle())
    }
}

private struct GeistStructuredStyle: StructuredText.Style {
    var inlineStyle: InlineStyle {
        InlineStyle()
            .code(.font(.custom("Recursive Mono", size: 13)),
                  .foregroundColor(Theme.fg),
                  .backgroundColor(Theme.surface))
            .strong(.fontWeight(.bold))
            .link(.foregroundColor(Theme.fg), .underlineStyle(.single))
            .strikethrough(.strikethroughStyle(Text.LineStyle(pattern: .solid, color: Theme.brand)),
                           .foregroundColor(Theme.brandDim))
    }

    var headingStyle: GeistHeadingStyle { GeistHeadingStyle() }
    var paragraphStyle: GeistParagraphStyle { GeistParagraphStyle() }
    var blockQuoteStyle: GeistBlockQuoteStyle { GeistBlockQuoteStyle() }
    var codeBlockStyle: GeistCodeBlockStyle { GeistCodeBlockStyle() }
    var listItemStyle: StructuredText.DefaultListItemStyle { .default }
    var unorderedListMarker: StructuredText.SymbolListMarker { .disc }
    var orderedListMarker: StructuredText.DecimalListMarker { .decimal }
    var tableStyle: GeistTableStyle { GeistTableStyle() }
    var tableCellStyle: GeistTableCellStyle { GeistTableCellStyle() }
    var thematicBreakStyle: GeistThematicBreakStyle { GeistThematicBreakStyle() }
}

private struct GeistHeadingStyle: StructuredText.HeadingStyle {
    private static let sizes: [CGFloat] = [24, 21, 19, 18, 17, 16]
    private static let weights: [Font.Weight] = [.bold, .semibold, .semibold, .semibold, .medium, .medium]
    private static let tops: [CGFloat] = [24, 22, 20, 18, 16, 16]
    private static let bottoms: [CGFloat] = [8, 6, 6, 4, 4, 4]

    func makeBody(configuration: Configuration) -> some View {
        let level = min(max(configuration.headingLevel, 1), 6)

        configuration.label
            .tracking(0.5)
            .font(.custom("Recursive Mono", size: Self.sizes[level - 1]))
            .fontWeight(Self.weights[level - 1])
            .foregroundStyle(Theme.fg)
            .textual.blockSpacing(StructuredText.BlockSpacing(top: Self.tops[level - 1],
                                                              bottom: Self.bottoms[level - 1]))
    }
}

private struct GeistParagraphStyle: StructuredText.ParagraphStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fixedSize(horizontal: false, vertical: true)
            .textual.lineSpacing(.fontScaled(0.2))
            .textual.blockSpacing(.fontScaled(top: 0.8))
    }
}

private struct GeistBlockQuoteStyle: StructuredText.BlockQuoteStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle().fill(Theme.controlBorder).frame(width: 2)
            configuration.label
                .foregroundStyle(Theme.dim)
        }
        .fixedSize(horizontal: false, vertical: true)
        .textual.blockSpacing(.fontScaled(top: 0.8))
    }
}

private struct GeistCodeBlockStyle: StructuredText.CodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        Overflow {
            configuration.label
                .textual.lineSpacing(.fontScaled(0.2))
                .font(.custom("Recursive Mono", size: 13))
                .foregroundStyle(Theme.fg)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 12)
                .padding(.leading, 12)
                .padding(.trailing, 48)
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
        .overlay(alignment: .topTrailing) {
            CodeCopyButton(codeBlock: configuration.codeBlock)
        }
        .textual.blockSpacing(.fontScaled(top: 0.8, bottom: 0.8))
    }
}

private struct CodeCopyButton: View {
    let codeBlock: StructuredText.CodeBlockProxy

    @ScaledMetric(relativeTo: .caption2) private var iconSize: CGFloat = 10

    @State private var copied = false

    var body: some View {
        Button {
            codeBlock.copyToPasteboard()
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            SwiftUI.Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(copied ? Theme.fg : Theme.dim)
                .padding(6)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.innerRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.innerRadius).stroke(Theme.chip, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.geist)
        .padding(6)
        .accessibilityLabel(copied ? Copy.Common.copied : Copy.Common.copy)
    }
}

private struct GeistTableStyle: StructuredText.TableStyle {
    func makeBody(configuration: Configuration) -> some View {
        Overflow { state in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: state.containerWidth,
                       maxWidth: state.containerWidth.map { $0 * 1.5 },
                       alignment: .leading)
                .textual.tableOverlay { layout in
                    Canvas { context, _ in
                        for divider in layout.dividers() {
                            context.fill(Path(divider), with: .color(Theme.chip))
                        }
                    }
                }
                .padding(1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.chip, lineWidth: 1))
        .textual.tableCellSpacing(horizontal: 1, vertical: 1)
        .textual.blockSpacing(.fontScaled(top: 0.8, bottom: 0.8))
    }
}

private struct GeistTableCellStyle: StructuredText.TableCellStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(configuration.row == 0 ? .semibold : .regular)
            .foregroundStyle(configuration.row == 0 ? Theme.fg : Theme.muted)
            .textual.lineSpacing(.fontScaled(0.2))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GeistThematicBreakStyle: StructuredText.ThematicBreakStyle {
    func makeBody(configuration: Configuration) -> some View {
        Hairline()
            .textual.blockSpacing(.fontScaled(top: 1, bottom: 1))
    }
}

private struct BlockedImageLoader: AttachmentLoader {
    func attachment(
        for url: URL,
        text: String,
        environment: ColorEnvironmentValues
    ) async throws -> BlockedImageAttachment {
        BlockedImageAttachment()
    }
}

private struct BlockedImageAttachment: Attachment {
    var description: String { Copy.Message.imageHidden }

    var body: some View {
        HStack(spacing: 7) {
            SwiftUI.Image(systemName: "photo")
                .font(.inco(.footnote))
                .accessibilityHidden(true)
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

    func sizeThatFits(_ proposal: ProposedViewSize, in environment: TextEnvironmentValues) -> CGSize {
        CGSize(width: proposal.width ?? 260, height: 40)
    }
}
