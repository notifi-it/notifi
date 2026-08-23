import Foundation

enum MarkdownPreview {
    static func text(_ source: String) -> String {
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

        let attributed = (try? AttributedString(
            markdown: flattened,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )) ?? AttributedString(flattened)

        return String(attributed.characters)
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
