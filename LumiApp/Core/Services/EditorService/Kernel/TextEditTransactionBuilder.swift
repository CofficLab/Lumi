import Foundation
import LanguageServerProtocol

enum TextEditTransactionBuilder {
    static func makeTransaction(edits: [TextEdit], in text: String) -> EditorTransaction? {
        var replacements: [EditorTransaction.Replacement] = []
        replacements.reserveCapacity(edits.count)

        for edit in edits {
            guard let nsRange = nsRange(from: edit.range, in: text) else {
                return nil
            }
            replacements.append(
                EditorTransaction.Replacement(
                    range: EditorRange(location: nsRange.location, length: nsRange.length),
                    text: edit.newText
                )
            )
        }

        return EditorTransaction(replacements: replacements)
    }

    private static func nsRange(from lspRange: LSPRange, in content: String) -> NSRange? {
        guard let start = utf16Offset(for: lspRange.start, in: content),
              let end = utf16Offset(for: lspRange.end, in: content),
              end >= start else {
            return nil
        }
        return NSRange(location: start, length: end - start)
    }

    private static func utf16Offset(for position: Position, in content: String) -> Int? {
        var line = 0
        var utf16Offset = 0
        var lineStartOffset = 0

        for scalar in content.unicodeScalars {
            if line == position.line {
                break
            }
            utf16Offset += scalar.utf16.count
            if scalar == "\n" {
                line += 1
                lineStartOffset = utf16Offset
            }
        }

        guard line == position.line else { return nil }
        return min(lineStartOffset + position.character, content.utf16.count)
    }
}
