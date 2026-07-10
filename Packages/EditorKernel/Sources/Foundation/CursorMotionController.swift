import Foundation

public struct CursorMotionTarget: Equatable, Sendable {
    public let location: Int
    public let selectionRange: NSRange?

    public init(location: Int, selectionRange: NSRange? = nil) {
        self.location = location
        self.selectionRange = selectionRange
    }
}

public enum CursorMotionController: Sendable {
    private static let crCode = UInt16(("\r" as UnicodeScalar).value)
    private static let lfCode = UInt16(("\n" as UnicodeScalar).value)

    public static func moveLeft(location: Int, text: String) -> CursorMotionTarget {
        let target = max(0, location - 1)
        return CursorMotionTarget(location: target)
    }

    public static func moveRight(location: Int, text: String) -> CursorMotionTarget {
        let length = (text as NSString).length
        let target = min(length, clampedLocation(location, length: length) + 1)
        return CursorMotionTarget(location: target)
    }

    public static func moveWordLeft(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let length = nsText.length
        let safeLocation = clampedLocation(location, length: length)
        guard safeLocation > 0, length > 0 else {
            return CursorMotionTarget(location: 0)
        }

        var pos = safeLocation
        while pos > 0, isWhitespace(nsText.character(at: pos - 1)) {
            pos -= 1
        }

        guard pos > 0 else {
            return CursorMotionTarget(location: 0)
        }

        let charType = characterType(nsText.character(at: pos - 1))
        while pos > 0, characterType(nsText.character(at: pos - 1)) == charType {
            pos -= 1
        }

        return CursorMotionTarget(location: pos)
    }

    public static func moveWordRight(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let length = nsText.length
        let safeLocation = clampedLocation(location, length: length)
        guard safeLocation < length, length > 0 else {
            return CursorMotionTarget(location: length)
        }

        var pos = safeLocation
        while pos < length, isWhitespace(nsText.character(at: pos)) {
            pos += 1
        }

        guard pos < length else {
            return CursorMotionTarget(location: length)
        }

        let charType = characterType(nsText.character(at: pos))
        while pos < length, characterType(nsText.character(at: pos)) == charType {
            pos += 1
        }

        return CursorMotionTarget(location: pos)
    }

    public static func deleteWordLeft(location: Int, text: String) -> CursorMotionTarget {
        let safeLocation = clampedLocation(location, length: (text as NSString).length)
        let target = moveWordLeft(location: safeLocation, text: text)
        return CursorMotionTarget(
            location: target.location,
            selectionRange: NSRange(location: target.location, length: safeLocation - target.location)
        )
    }

    public static func deleteWordRight(location: Int, text: String) -> CursorMotionTarget {
        let safeLocation = clampedLocation(location, length: (text as NSString).length)
        let target = moveWordRight(location: safeLocation, text: text)
        return CursorMotionTarget(
            location: safeLocation,
            selectionRange: NSRange(location: safeLocation, length: target.location - safeLocation)
        )
    }

    public static func moveToBeginningOfLine(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let safeLocation = clampedLocation(location, length: nsText.length)
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
        return CursorMotionTarget(location: lineRange.location)
    }

    public static func moveToEndOfLine(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let textLength = nsText.length
        let safeLocation = clampedLocation(location, length: textLength)
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
        let lineEnd = NSMaxRange(lineRange)
        let target: Int
        if lineEnd > 0, lineEnd <= textLength {
            if lineEnd > lineRange.location + 1,
               nsText.character(at: lineEnd - 2) == Self.crCode,
               nsText.character(at: lineEnd - 1) == Self.lfCode {
                target = lineEnd - 2
            } else if lineEnd > lineRange.location,
                      nsText.character(at: lineEnd - 1) == Self.lfCode {
                target = lineEnd - 1
            } else {
                target = lineEnd
            }
        } else {
            target = lineEnd
        }
        return CursorMotionTarget(location: target)
    }

    public static func smartHome(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let textLength = nsText.length
        let safeLocation = clampedLocation(location, length: textLength)
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
        let lineStart = lineRange.location

        let firstNonWhitespace = firstNonWhitespaceOffset(
            in: nsText,
            lineStart: lineStart,
            lineEnd: NSMaxRange(lineRange)
        )

        let lineHome = lineStart
        let contentHome = lineStart + firstNonWhitespace

        if lineHome == contentHome {
            return CursorMotionTarget(location: lineHome)
        }

        if safeLocation <= lineHome {
            return CursorMotionTarget(location: contentHome)
        }

        if safeLocation >= contentHome {
            return CursorMotionTarget(location: lineHome)
        }

        return CursorMotionTarget(location: contentHome)
    }

    public static func moveUp(location: Int, text: String, desiredColumn: Int?) -> CursorMotionTarget {
        let nsText = text as NSString
        let textLength = nsText.length
        let safeLocation = clampedLocation(location, length: textLength)
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))

        guard lineRange.location > 0 else {
            return CursorMotionTarget(location: 0)
        }

        let prevLineEnd = lineRange.location - 1
        let prevLineRange = nsText.lineRange(for: NSRange(location: max(0, prevLineEnd), length: 0))

        let column = desiredColumn ?? (safeLocation - lineRange.location)
        let prevLineLength = lineContentLength(nsText, lineRange: prevLineRange)
        let targetColumn = min(column, prevLineLength)
        let target = prevLineRange.location + targetColumn

        return CursorMotionTarget(location: target)
    }

    public static func moveDown(location: Int, text: String, desiredColumn: Int?) -> CursorMotionTarget {
        let nsText = text as NSString
        let textLength = nsText.length
        let safeLocation = clampedLocation(location, length: textLength)
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
        let lineEnd = NSMaxRange(lineRange)

        guard lineEnd < textLength else {
            return CursorMotionTarget(location: textLength)
        }

        let nextLineRange = nsText.lineRange(for: NSRange(location: lineEnd, length: 0))

        let column = desiredColumn ?? (safeLocation - lineRange.location)
        let nextLineLength = lineContentLength(nsText, lineRange: nextLineRange)
        let targetColumn = min(column, nextLineLength)
        let target = nextLineRange.location + targetColumn

        return CursorMotionTarget(location: target)
    }

    public static func moveToDocumentStart() -> CursorMotionTarget {
        CursorMotionTarget(location: 0)
    }

    public static func moveToDocumentEnd(text: String) -> CursorMotionTarget {
        CursorMotionTarget(location: (text as NSString).length)
    }

    public static func moveParagraphBackward(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let textLength = nsText.length
        guard textLength > 0 else { return CursorMotionTarget(location: 0) }

        let currentLineStart = lineStart(containing: clampedLocation(location, length: textLength), in: nsText)

        if isLineEmpty(nsText, at: currentLineStart) {
            var pos = currentLineStart

            while pos > 0 {
                let prevLineRange = nsText.lineRange(for: NSRange(location: pos - 1, length: 0))
                if isLineEmpty(nsText, at: prevLineRange.location) {
                    pos = prevLineRange.location
                    continue
                }

                var paragraphStart = prevLineRange.location
                while paragraphStart > 0 {
                    let candidateRange = nsText.lineRange(for: NSRange(location: paragraphStart - 1, length: 0))
                    if isLineEmpty(nsText, at: candidateRange.location) {
                        break
                    }
                    paragraphStart = candidateRange.location
                }
                return CursorMotionTarget(location: paragraphStart)
            }

            return CursorMotionTarget(location: 0)
        }

        var pos = currentLineStart
        while pos > 0 {
            let prevLineRange = nsText.lineRange(for: NSRange(location: pos - 1, length: 0))
            if isLineEmpty(nsText, at: prevLineRange.location) {
                var emptyBlockStart = prevLineRange.location
                while emptyBlockStart > 0 {
                    let candidateRange = nsText.lineRange(for: NSRange(location: emptyBlockStart - 1, length: 0))
                    if !isLineEmpty(nsText, at: candidateRange.location) {
                        break
                    }
                    emptyBlockStart = candidateRange.location
                }
                return CursorMotionTarget(location: emptyBlockStart)
            }
            pos = prevLineRange.location
        }

        return CursorMotionTarget(location: 0)
    }

    public static func moveParagraphForward(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let textLength = nsText.length
        guard textLength > 0 else { return CursorMotionTarget(location: textLength) }

        let currentLineStart = lineStart(containing: clampedLocation(location, length: textLength), in: nsText)
        let currentLineRange = nsText.lineRange(for: NSRange(location: currentLineStart, length: 0))

        if isLineEmpty(nsText, at: currentLineStart) {
            var pos = NSMaxRange(currentLineRange)
            while pos < textLength {
                let lineRange = nsText.lineRange(for: NSRange(location: pos, length: 0))
                if !isLineEmpty(nsText, at: lineRange.location) {
                    return CursorMotionTarget(location: lineRange.location)
                }
                pos = NSMaxRange(lineRange)
            }
            return CursorMotionTarget(location: textLength)
        }

        var pos = NSMaxRange(currentLineRange)
        while pos < textLength {
            let lineRange = nsText.lineRange(for: NSRange(location: pos, length: 0))
            if isLineEmpty(nsText, at: lineRange.location) {
                return CursorMotionTarget(location: lineRange.location)
            }
            pos = NSMaxRange(lineRange)
        }

        return CursorMotionTarget(location: textLength)
    }

    private enum CharCategory: Equatable, Sendable {
        case word
        case separator
        case operator_
    }

    private static func characterType(_ char: UInt16) -> CharCategory {
        if isWhitespace(char) {
            return .separator
        }
        if isWordCharacter(char) {
            return .word
        }
        return .operator_
    }

    private static func isWhitespace(_ char: UInt16) -> Bool {
        char == 0x20 || char == 0x09 || char == 0x0A || char == 0x0D || char == 0x0C
    }

    private static func isWordCharacter(_ char: UInt16) -> Bool {
        (char >= 0x30 && char <= 0x39) ||
        (char >= 0x41 && char <= 0x5A) ||
        (char >= 0x61 && char <= 0x7A) ||
        char == 0x5F
    }

    private static func clampedLocation(_ location: Int, length: Int) -> Int {
        min(max(location, 0), length)
    }

    private static func firstNonWhitespaceOffset(
        in nsText: NSString,
        lineStart: Int,
        lineEnd: Int
    ) -> Int {
        var offset = 0
        var pos = lineStart
        while pos < lineEnd {
            let char = nsText.character(at: pos)
            if char != 0x20 && char != 0x09 {
                return offset
            }
            offset += 1
            pos += 1
        }
        return offset
    }

    private static func lineContentLength(_ nsText: NSString, lineRange: NSRange) -> Int {
        var length = lineRange.length
        if length > 0 && nsText.character(at: NSMaxRange(lineRange) - 1) == 0x0A {
            length -= 1
            if length > 0 && nsText.character(at: NSMaxRange(lineRange) - 2) == 0x0D {
                length -= 1
            }
        }
        return length
    }

    private static func isLineEmpty(_ nsText: NSString, at position: Int) -> Bool {
        guard position >= 0, position < nsText.length else { return true }
        let lineRange = nsText.lineRange(for: NSRange(location: position, length: 0))
        if lineRange.length == 0 { return true }
        var pos = lineRange.location
        let end = NSMaxRange(lineRange)
        while pos < end {
            let char = nsText.character(at: pos)
            if char != 0x20 && char != 0x09 && char != 0x0A && char != 0x0D {
                return false
            }
            pos += 1
        }
        return true
    }

    private static func lineStart(containing location: Int, in nsText: NSString) -> Int {
        guard nsText.length > 0 else { return 0 }
        let safeLocation = clampedLocation(location, length: nsText.length)
        let anchor = safeLocation == nsText.length ? max(0, safeLocation - 1) : safeLocation
        return nsText.lineRange(for: NSRange(location: anchor, length: 0)).location
    }
}
