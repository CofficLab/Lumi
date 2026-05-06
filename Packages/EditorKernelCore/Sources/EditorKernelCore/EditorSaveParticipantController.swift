import Foundation

public struct EditorSaveParticipantOptions: Equatable, Sendable {
    public var trimTrailingWhitespace: Bool
    public var insertFinalNewline: Bool

    public static let `default` = EditorSaveParticipantOptions(
        trimTrailingWhitespace: true,
        insertFinalNewline: true
    )

    public init(trimTrailingWhitespace: Bool, insertFinalNewline: Bool) {
        self.trimTrailingWhitespace = trimTrailingWhitespace
        self.insertFinalNewline = insertFinalNewline
    }
}

public struct EditorSaveParticipantResult: Equatable, Sendable {
    public let text: String
    public let didTrimTrailingWhitespace: Bool
    public let didInsertFinalNewline: Bool

    public var changed: Bool {
        didTrimTrailingWhitespace || didInsertFinalNewline
    }

    public init(text: String, didTrimTrailingWhitespace: Bool, didInsertFinalNewline: Bool) {
        self.text = text
        self.didTrimTrailingWhitespace = didTrimTrailingWhitespace
        self.didInsertFinalNewline = didInsertFinalNewline
    }
}

public enum EditorSaveParticipantController {
    public static func prepare(
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
