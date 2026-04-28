import Foundation

struct EditorSaveParticipantOptions: Equatable, Sendable {
    var trimTrailingWhitespace: Bool
    var insertFinalNewline: Bool

    static let `default` = EditorSaveParticipantOptions(
        trimTrailingWhitespace: true,
        insertFinalNewline: true
    )
}

struct EditorSaveParticipantResult: Equatable, Sendable {
    let text: String
    let didTrimTrailingWhitespace: Bool
    let didInsertFinalNewline: Bool

    var changed: Bool {
        didTrimTrailingWhitespace || didInsertFinalNewline
    }
}

enum EditorSaveParticipantController {
    static func prepare(
        text: String,
        options: EditorSaveParticipantOptions = .default
    ) -> EditorSaveParticipantResult {
        var transformed = text
        var didTrimTrailingWhitespace = false
        var didInsertFinalNewline = false

        if options.trimTrailingWhitespace {
            let trimmed = trimTrailingWhitespace(in: transformed)
            didTrimTrailingWhitespace = trimmed != transformed
            transformed = trimmed
        }

        if options.insertFinalNewline,
           transformed.isEmpty == false,
           transformed.hasSuffix("\n") == false {
            transformed.append(preferredLineEnding(in: transformed))
            didInsertFinalNewline = true
        }

        return EditorSaveParticipantResult(
            text: transformed,
            didTrimTrailingWhitespace: didTrimTrailingWhitespace,
            didInsertFinalNewline: didInsertFinalNewline
        )
    }

    private static func trimTrailingWhitespace(in text: String) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            let lineStart = index
            while index < text.endIndex,
                  text[index] != "\n",
                  text[index] != "\r" {
                index = text.index(after: index)
            }

            result.append(
                String(text[lineStart..<index])
                    .trimmingCharacters(in: .whitespaces)
            )

            guard index < text.endIndex else { break }

            if text[index] == "\r" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    result.append("\r\n")
                    index = text.index(after: nextIndex)
                } else {
                    result.append("\r")
                    index = nextIndex
                }
            } else {
                result.append("\n")
                index = text.index(after: index)
            }
        }

        return result
    }

    private static func preferredLineEnding(in text: String) -> String {
        if text.contains("\r\n") {
            return "\r\n"
        }
        if text.contains("\r") {
            return "\r"
        }
        return "\n"
    }
}
