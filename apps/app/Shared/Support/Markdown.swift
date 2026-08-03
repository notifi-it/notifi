import MarkdownUI
import SwiftUI

// Message bodies are written by whoever sends the notification, so they arrive as
// plain text that may or may not be Markdown. Rendering is best-effort either way:
// a body that was never meant to be Markdown still reads as itself.
//
// Note on naming: `Theme` in this file is always the app's design system. The
// library's own theme type is written out as `MarkdownUI.Theme`.

/// A message body rendered as Markdown, styled to the Geist system.
///
/// A body can carry `![](https://…)`, which the library would fetch as the view
/// appears. That is the same disclosure as the message's own image field — the
/// host learns the device's IP address — so it is gated on the same decision.
struct MarkdownText: View {
    let source: String
    /// Whether the key that sent this message is allowed to open non-https links.
    let allowAnyScheme: Bool
    var allowsRemoteImages: Bool = false

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
        // A body link shows only its label, so the scheme behind it is never on
        // screen. It goes through the same policy as the message's own `link`
        // field rather than straight to the OS.
        .environment(\.openURL, OpenURLAction { url in
            LinkPolicy.allows(url, anyScheme: allowAnyScheme) ? .systemAction : .discarded
        })
    }

    private var markdown: some View {
        Markdown(source).markdownTheme(.geist)
    }
}

private struct RemoteImageBlocked: Error {}

private struct BlockedImageProvider: ImageProvider {
    func makeImage(url: URL?) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "photo")
                .font(.system(size: 12, weight: .medium))
            Text("Image hidden")
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
    /// Karla for prose, Inconsolata for code and headings — the same split the rest
    /// of the app uses.
    ///
    /// Every size below is a step on the app's type scale (see `Font.incoSize`):
    /// 20 is title3, 17 headline, 15 subheadline, 13 footnote. `Font.custom(_:size:)`
    /// still scales with Dynamic Type, so these are not frozen points.
    ///
    /// Computed rather than `static let`: the theme builders are main-actor bound,
    /// so a stored global would need `nonisolated(unsafe)` to satisfy Swift 6.
    @MainActor
    static var geist: MarkdownUI.Theme {
        MarkdownUI.Theme()
        .text {
            FontFamily(.custom("Karla"))
            FontSize(15)
            ForegroundColor(Theme.muted)
        }
        .strong {
            FontWeight(.semibold)
            ForegroundColor(Theme.fg)
        }
        .code {
            FontFamily(.custom("Inconsolata"))
            FontSize(15)
            ForegroundColor(Theme.fg)
        }
        .link {
            // Not brand red. Red is the unread marker and the wordmark dot and
            // nothing else, so a red link would give it a third meaning. Links
            // earn their emphasis from the underline instead.
            ForegroundColor(Theme.fg)
            UnderlineStyle(.single)
        }
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: .em(1), bottom: .em(0.3))
                .markdownTextStyle {
                    FontFamily(.custom("Inconsolata"))
                    FontSize(20)
                    FontWeight(.bold)
                    ForegroundColor(Theme.fg)
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: .em(1), bottom: .em(0.3))
                .markdownTextStyle {
                    FontFamily(.custom("Inconsolata"))
                    FontSize(17)
                    FontWeight(.bold)
                    ForegroundColor(Theme.fg)
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: .em(0.8), bottom: .em(0.2))
                .markdownTextStyle {
                    FontFamily(.custom("Inconsolata"))
                    FontSize(15)
                    FontWeight(.semibold)
                    ForegroundColor(Theme.fg)
                }
        }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.2))
                .markdownMargin(top: .em(0.8))
        }
        .blockquote { configuration in
            HStack(alignment: .top, spacing: 10) {
                Rectangle().fill(Theme.chip).frame(width: 2)
                configuration.label
                    .markdownTextStyle { ForegroundColor(Theme.dim) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .markdownMargin(top: .em(0.8))
        }
        .codeBlock { configuration in
            // Code is the one place that must not reflow, so it scrolls sideways
            // rather than wrapping mid-token.
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .relativeLineSpacing(.em(0.2))
                    .markdownTextStyle {
                        FontFamily(.custom("Inconsolata"))
                        FontSize(13)
                        ForegroundColor(Theme.fg)
                    }
                    .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
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
}

// MARK: - Row preview

/// The inbox row shows two lines, so it gets a flattened, inline-only rendering
/// rather than the block layout: markers dropped, line breaks collapsed, bold and
/// code still styled. A bulleted body previews as prose instead of as dashes.
enum MarkdownPreview {
    static func text(_ source: String) -> AttributedString {
        let flattened = source
            .components(separatedBy: .newlines)
            .map { line -> String in
                var trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("```") { return "" }
                while let first = trimmed.first, first == "#" || first == ">" {
                    trimmed = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                return stripListMarker(trimmed)
            }
            .filter { !$0.isEmpty && !isRule($0) }
            .joined(separator: " ")

        var attributed = (try? AttributedString(
            markdown: flattened,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )) ?? AttributedString(flattened)

        // Bold and italic ride the base font; code has to switch typeface, and that
        // only happens per-run.
        for run in attributed.runs where run.inlinePresentationIntent?.contains(.code) == true {
            attributed[run.range].font = .inco(.footnote)
        }
        return attributed
    }

    private static func stripListMarker(_ line: String) -> String {
        if let first = line.first, "-*+".contains(first), line.dropFirst().first == " " {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        let digits = line.prefix { $0.isNumber }
        if !digits.isEmpty {
            let rest = line.dropFirst(digits.count)
            if rest.first == "." || rest.first == ")", rest.dropFirst().first == " " {
                return String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return line
    }

    private static func isRule(_ line: String) -> Bool {
        guard line.count >= 3, let first = line.first, "-*_".contains(first) else { return false }
        return line.allSatisfy { $0 == first }
    }
}
