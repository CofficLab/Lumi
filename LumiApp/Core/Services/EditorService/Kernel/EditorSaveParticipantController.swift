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
        let nsText = text as NSString
        let trailingWhitespace = CharacterSet(charactersIn: " \t")
        var result = ""
        var location = 0

        while location < nsText.length {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            nsText.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))

            var trimmedContentsEnd = contentsEnd
            while trimmedContentsEnd > lineStart {
                let scalar = nsText.character(at: trimmedContentsEnd - 1)
                guard let unicodeScalar = UnicodeScalar(scalar),
                      trailingWhitespace.contains(unicodeScalar) else {
                    break
                }
                trimmedContentsEnd -= 1
            }

            result += nsText.substring(with: NSRange(location: lineStart, length: trimmedContentsEnd - lineStart))
            if lineEnd > contentsEnd {
                result += nsText.substring(with: NSRange(location: contentsEnd, length: lineEnd - contentsEnd))
            }

            location = lineEnd
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
