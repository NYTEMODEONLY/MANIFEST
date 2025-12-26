import Foundation

/// Extracts README preview content with markdown stripping
actor ReadmeExtractor {

    /// Extracts the first N characters from a README file
    func extractPreview(from url: URL, maxLength: Int = 300) async -> String? {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        let cleanContent = cleanMarkdown(content)

        if cleanContent.count <= maxLength {
            return cleanContent.isEmpty ? nil : cleanContent
        }

        // Truncate at word boundary
        let truncated = String(cleanContent.prefix(maxLength))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }

        return truncated + "..."
    }

    /// Strips markdown formatting for cleaner preview
    private func cleanMarkdown(_ content: String) -> String {
        var cleaned = content

        // Remove YAML frontmatter (---...---)
        if cleaned.hasPrefix("---") {
            if let endRange = cleaned.range(
                of: "---",
                range: cleaned.index(cleaned.startIndex, offsetBy: 3)..<cleaned.endIndex
            ) {
                cleaned = String(cleaned[endRange.upperBound...])
            }
        }

        // Remove headers (# symbols at start of lines)
        cleaned = cleaned.replacingOccurrences(
            of: "(?m)^#+\\s*",
            with: "",
            options: .regularExpression
        )

        // Remove emphasis markers
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "__", with: "")
        cleaned = cleaned.replacingOccurrences(of: "*", with: "")
        cleaned = cleaned.replacingOccurrences(of: "_", with: "")

        // Remove links [text](url) -> text
        cleaned = cleaned.replacingOccurrences(
            of: "\\[([^\\]]+)\\]\\([^)]+\\)",
            with: "$1",
            options: .regularExpression
        )

        // Remove images
        cleaned = cleaned.replacingOccurrences(
            of: "!\\[([^\\]]*)\\]\\([^)]+\\)",
            with: "",
            options: .regularExpression
        )

        // Remove code blocks
        cleaned = cleaned.replacingOccurrences(
            of: "```[\\s\\S]*?```",
            with: "",
            options: .regularExpression
        )

        // Remove inline code
        cleaned = cleaned.replacingOccurrences(of: "`", with: "")

        // Normalize whitespace
        cleaned = cleaned.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
