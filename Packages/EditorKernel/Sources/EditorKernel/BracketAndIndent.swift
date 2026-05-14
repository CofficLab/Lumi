import Foundation

public struct BracketPair: Hashable, Sendable {
    public let open: Character
    public let close: Character

    public init(open: Character, close: Character) {
        self.open = open
        self.close = close
    }

    public func matchesClose(_ char: Character) -> Bool {
        close == char
    }

    public func matchesOpen(_ char: Character) -> Bool {
        open == char
    }
}

public struct BracketPairsConfig: Sendable {
    public let pairs: [BracketPair]
    public let autoClosingPairs: [AutoClosingPair]

    public init(
        pairs: [BracketPair],
        autoClosingPairs: [AutoClosingPair]? = nil
    ) {
        self.pairs = pairs
        self.autoClosingPairs = autoClosingPairs ?? pairs.map { pair in
            AutoClosingPair(open: pair.open, close: pair.close)
        }
    }

    public static func defaultForLanguage(_ languageId: String) -> BracketPairsConfig {
        let commonPairs: [BracketPair] = [
            BracketPair(open: "(", close: ")"),
            BracketPair(open: "[", close: "]"),
            BracketPair(open: "{", close: "}"),
        ]

        let quotePairs: [BracketPair] = [
            BracketPair(open: "\"", close: "\""),
            BracketPair(open: "'", close: "'"),
            BracketPair(open: "`", close: "`"),
        ]

        switch languageId {
        case "html", "xml":
            return BracketPairsConfig(
                pairs: [
                    BracketPair(open: "<", close: ">"),
                ],
                autoClosingPairs: []
            )
        case "css", "scss", "sass", "less":
            return BracketPairsConfig(
                pairs: commonPairs + [
                    BracketPair(open: "\"", close: "\""),
                    BracketPair(open: "'", close: "'"),
                ]
            )
        case "python":
            return BracketPairsConfig(
                pairs: commonPairs + quotePairs,
                autoClosingPairs: [
                    AutoClosingPair(open: "(", close: ")"),
                    AutoClosingPair(open: "[", close: "]"),
                    AutoClosingPair(open: "{", close: "}"),
                    AutoClosingPair(open: "\"", close: "\"", notIn: [.string]),
                    AutoClosingPair(open: "'", close: "'", notIn: [.string]),
                ]
            )
        default:
            return BracketPairsConfig(pairs: commonPairs + quotePairs)
        }
    }

    public func matchingClose(for open: Character) -> Character? {
        pairs.first(where: { $0.open == open })?.close
    }

    public func matchingOpen(for close: Character) -> Character? {
        pairs.first(where: { $0.close == close })?.open
    }

    public func isOpenBracket(_ char: Character) -> Bool {
        pairs.contains { $0.open == char }
    }

    public func isCloseBracket(_ char: Character) -> Bool {
        pairs.contains { $0.close == char }
    }
}

public struct AutoClosingPair: Hashable, Sendable {
    public let open: Character
    public let close: Character
    public let notIn: [AutoClosingContext]

    public init(open: Character, close: Character, notIn: [AutoClosingContext] = []) {
        self.open = open
        self.close = close
        self.notIn = notIn
    }
}

public enum AutoClosingContext: Hashable, Sendable {
    case string
    case comment
    case regex
}

public enum BracketMatcher {
    public struct AutoClosingEdit: Equatable, Sendable {
        public let replacementRange: NSRange
        public let replacementText: String
        public let selectedRange: NSRange

        public init(replacementRange: NSRange, replacementText: String, selectedRange: NSRange) {
            self.replacementRange = replacementRange
            self.replacementText = replacementText
            self.selectedRange = selectedRange
        }
    }

    public struct MatchResult {
        public let openPosition: Int
        public let closePosition: Int

        public init(openPosition: Int, closePosition: Int) {
            self.openPosition = openPosition
            self.closePosition = closePosition
        }
    }

    public static func findMatchingBracket(
        in text: String,
        at cursorPosition: Int,
        config: BracketPairsConfig
    ) -> MatchResult? {
        let textLength = text.utf16.count
        guard cursorPosition >= 0, cursorPosition <= textLength else { return nil }

        if cursorPosition > 0 {
            let openIndex = text.utf16.index(text.utf16.startIndex, offsetBy: cursorPosition - 1)
            if let scalar = Unicode.Scalar(text.utf16[openIndex]),
               let closeChar = config.matchingClose(for: Character(scalar)) {
                if let closePos = findCloseBracket(
                    in: text,
                    from: cursorPosition,
                    openChar: Character(scalar),
                    closeChar: closeChar
                ) {
                    return MatchResult(openPosition: cursorPosition - 1, closePosition: closePos)
                }
            }
        }

        if cursorPosition < textLength {
            let openIndex = text.utf16.index(text.utf16.startIndex, offsetBy: cursorPosition)
            if let scalar = Unicode.Scalar(text.utf16[openIndex]),
               let closeChar = config.matchingClose(for: Character(scalar)) {
                if let closePos = findCloseBracket(
                    in: text,
                    from: cursorPosition + 1,
                    openChar: Character(scalar),
                    closeChar: closeChar
                ) {
                    return MatchResult(openPosition: cursorPosition, closePosition: closePos)
                }
            }
        }

        if cursorPosition < textLength {
            let closeIndex = text.utf16.index(text.utf16.startIndex, offsetBy: cursorPosition)
            if let scalar = Unicode.Scalar(text.utf16[closeIndex]),
               let openChar = config.matchingOpen(for: Character(scalar)) {
                if let openPos = findOpenBracket(
                    in: text,
                    from: cursorPosition - 1,
                    openChar: openChar,
                    closeChar: Character(scalar)
                ) {
                    return MatchResult(openPosition: openPos, closePosition: cursorPosition)
                }
            }
        }

        if cursorPosition > 0 {
            let closeIndex = text.utf16.index(text.utf16.startIndex, offsetBy: cursorPosition - 1)
            if let scalar = Unicode.Scalar(text.utf16[closeIndex]),
               let openChar = config.matchingOpen(for: Character(scalar)) {
                if let openPos = findOpenBracket(
                    in: text,
                    from: cursorPosition - 2,
                    openChar: openChar,
                    closeChar: Character(scalar)
                ) {
                    return MatchResult(openPosition: openPos, closePosition: cursorPosition - 1)
                }
            }
        }

        return nil
    }

    public static func shouldAutoClose(
        in text: String,
        at position: Int,
        typedChar: Character,
        config: BracketPairsConfig
    ) -> Character? {
        guard let autoPair = config.autoClosingPairs.first(where: { $0.open == typedChar }) else {
            return nil
        }

        if autoPair.notIn.contains(.string), isInStringContext(text, position: position) {
            return nil
        }
        if autoPair.notIn.contains(.comment), isInCommentContext(text, position: position) {
            return nil
        }

        return autoPair.close
    }

    public static func shouldAutoSurround(
        typedChar: Character,
        config: BracketPairsConfig
    ) -> Bool {
        config.pairs.contains { $0.open == typedChar } ||
        config.pairs.contains { $0.close == typedChar }
    }

    public static func autoClosingEdit(
        in text: String,
        selection: NSRange,
        typedChar: Character,
        config: BracketPairsConfig
    ) -> AutoClosingEdit? {
        let nsText = text as NSString
        guard selection.location != NSNotFound,
              selection.location >= 0,
              selection.length >= 0,
              NSMaxRange(selection) <= nsText.length else {
            return nil
        }

        if selection.length > 0,
           shouldAutoSurround(typedChar: typedChar, config: config),
           let pair = surroundingPair(for: typedChar, config: config) {
            let selectedText = nsText.substring(with: selection)
            let replacementText = String(pair.open) + selectedText + String(pair.close)
            return AutoClosingEdit(
                replacementRange: selection,
                replacementText: replacementText,
                selectedRange: NSRange(
                    location: selection.location + replacementText.count,
                    length: 0
                )
            )
        }

        if selection.length == 0,
           selection.location < nsText.length,
           let nextChar = nsText.substring(with: NSRange(location: selection.location, length: 1)).first,
           nextChar == typedChar,
           config.isCloseBracket(typedChar) {
            return AutoClosingEdit(
                replacementRange: NSRange(location: selection.location, length: 0),
                replacementText: "",
                selectedRange: NSRange(location: selection.location + 1, length: 0)
            )
        }

        if selection.length == 0,
           let closeChar = shouldAutoClose(
                in: text,
                at: selection.location,
                typedChar: typedChar,
                config: config
           ) {
            let replacementText = String(typedChar) + String(closeChar)
            return AutoClosingEdit(
                replacementRange: selection,
                replacementText: replacementText,
                selectedRange: NSRange(location: selection.location + 1, length: 0)
            )
        }

        return nil
    }

    private static func findCloseBracket(
        in text: String,
        from startIndex: Int,
        openChar: Character,
        closeChar: Character
    ) -> Int? {
        let utf16View = text.utf16
        var depth = 1
        var index = startIndex

        while index < utf16View.count {
            let charIndex = utf16View.index(utf16View.startIndex, offsetBy: index)
            if let scalar = Unicode.Scalar(utf16View[charIndex]) {
                let char = Character(scalar)
                if char == openChar {
                    depth += 1
                } else if char == closeChar {
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                }
            }
            index += 1
        }

        return nil
    }

    private static func surroundingPair(
        for typedChar: Character,
        config: BracketPairsConfig
    ) -> BracketPair? {
        if let pair = config.pairs.first(where: { $0.open == typedChar }) {
            return pair
        }
        if let pair = config.pairs.first(where: { $0.close == typedChar }) {
            return pair
        }
        return nil
    }

    private static func findOpenBracket(
        in text: String,
        from startIndex: Int,
        openChar: Character,
        closeChar: Character
    ) -> Int? {
        let utf16View = text.utf16
        var depth = 1
        var index = startIndex

        while index >= 0 {
            let charIndex = utf16View.index(utf16View.startIndex, offsetBy: index)
            if let scalar = Unicode.Scalar(utf16View[charIndex]) {
                let char = Character(scalar)
                if char == closeChar {
                    depth += 1
                } else if char == openChar {
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                }
            }
            index -= 1
        }

        return nil
    }

    private static func isInStringContext(_ text: String, position: Int) -> Bool {
        var doubleQuoteCount = 0
        var singleQuoteCount = 0
        var backslashCount = 0

        for (index, scalar) in text.unicodeScalars.enumerated() {
            guard index < position else { break }
            if scalar == "\\" {
                backslashCount += 1
                continue
            }
            if backslashCount % 2 == 0 {
                if scalar == "\"" { doubleQuoteCount += 1 }
                if scalar == "'" { singleQuoteCount += 1 }
            }
            backslashCount = 0
        }

        return doubleQuoteCount % 2 != 0 || singleQuoteCount % 2 != 0
    }

    private static func isInCommentContext(_ text: String, position: Int) -> Bool {
        let prefix = String(text.prefix(position))
        let lines = prefix.components(separatedBy: "\n")
        guard let lastLine = lines.last else { return false }
        return lastLine.contains("//")
    }
}

public enum SmartIndentHandler {
    public struct IndentResult {
        public let textToInsert: String
        public let cursorOffset: Int

        public init(textToInsert: String, cursorOffset: Int) {
            self.textToInsert = textToInsert
            self.cursorOffset = cursorOffset
        }
    }

    public struct OutdentResult: Equatable, Sendable {
        public let replacementRange: NSRange
        public let replacementText: String
        public let selectedRange: NSRange

        public init(replacementRange: NSRange, replacementText: String, selectedRange: NSRange) {
            self.replacementRange = replacementRange
            self.replacementText = replacementText
            self.selectedRange = selectedRange
        }
    }

    public static func handleEnter(
        in text: String,
        at position: Int,
        tabSize: Int,
        useSpaces: Bool
    ) -> IndentResult {
        let nsText = text as NSString
        let safePosition = min(max(0, position), nsText.length)
        let indent = indentString(tabSize: tabSize, useSpaces: useSpaces)
        let newline = newlineString(in: text)

        let anchor = safePosition == nsText.length ? max(0, safePosition - 1) : safePosition
        let lineRange = nsText.lineRange(for: NSRange(location: anchor, length: 0))
        let currentLineText = nsText.substring(with: lineRange)

        let leadingWhitespace = currentLineText.prefix(while: { $0 == " " || $0 == "\t" })
        let leadingWhitespaceLength = (String(leadingWhitespace) as NSString).length
        let indentLength = (indent as NSString).length
        let newlineLength = (newline as NSString).length

        let prevChar: Character? = safePosition > 0
            ? nsText.substring(with: NSRange(location: safePosition - 1, length: 1)).first
            : nil
        let nextChar: Character? = safePosition < nsText.length
            ? nsText.substring(with: NSRange(location: safePosition, length: 1)).first
            : nil

        if prevChar == "{", nextChar == "}" {
            let newText = newline + String(leadingWhitespace) + indent + newline + String(leadingWhitespace)
            return IndentResult(
                textToInsert: newText,
                cursorOffset: leadingWhitespaceLength + indentLength + newlineLength
            )
        }

        if let prev = prevChar, prev == "{" || prev == "(" || prev == "[" {
            let newText = newline + String(leadingWhitespace) + indent
            return IndentResult(
                textToInsert: newText,
                cursorOffset: leadingWhitespaceLength + indentLength + newlineLength
            )
        }

        let newText = newline + String(leadingWhitespace)
        return IndentResult(
            textToInsert: newText,
            cursorOffset: leadingWhitespaceLength + newlineLength
        )
    }

    public static func handleTab(
        at position: Int,
        hasSelection: Bool,
        selectionStart: Int,
        selectionEnd: Int,
        tabSize: Int,
        useSpaces: Bool
    ) -> IndentResult {
        let indent = indentString(tabSize: tabSize, useSpaces: useSpaces)
        return IndentResult(
            textToInsert: indent,
            cursorOffset: indent.count
        )
    }

    public static func handleTab(
        in text: String,
        selection: NSRange,
        tabSize: Int,
        useSpaces: Bool
    ) -> OutdentResult? {
        let nsText = text as NSString
        guard selection.location != NSNotFound,
              selection.location >= 0,
              selection.length >= 0,
              NSMaxRange(selection) <= nsText.length else {
            return nil
        }

        let indentUnit = indentString(tabSize: tabSize, useSpaces: useSpaces)
        let affectedLineStarts = lineStarts(in: text, selection: selection)
        guard !affectedLineStarts.isEmpty else { return nil }

        var updatedText = text
        for lineStart in affectedLineStarts.sorted(by: >) {
            guard let stringIndex = utf16StringIndex(in: updatedText, offset: lineStart) else {
                return nil
            }
            updatedText.insert(contentsOf: indentUnit, at: stringIndex)
        }

        let updatedSelection = adjustedSelectionForIndent(
            original: selection,
            lineStarts: affectedLineStarts,
            indentLength: (indentUnit as NSString).length
        )

        return OutdentResult(
            replacementRange: NSRange(location: 0, length: nsText.length),
            replacementText: updatedText,
            selectedRange: updatedSelection
        )
    }

    public static func handleBacktab(
        in text: String,
        selection: NSRange,
        tabSize: Int,
        useSpaces: Bool
    ) -> OutdentResult? {
        let nsText = text as NSString
        guard selection.location != NSNotFound,
              selection.location >= 0,
              selection.length >= 0,
              NSMaxRange(selection) <= nsText.length else {
            return nil
        }

        let indentUnit = indentString(tabSize: tabSize, useSpaces: useSpaces)
        let affectedLineStarts = lineStarts(in: text, selection: selection)
        guard !affectedLineStarts.isEmpty else { return nil }

        var removedRanges: [NSRange] = []
        for lineStart in affectedLineStarts {
            let lineRange = nsText.lineRange(for: NSRange(location: lineStart, length: 0))
            let lineText = nsText.substring(with: lineRange)
            let removalLength = outdentWidth(in: lineText, indentUnit: indentUnit, tabSize: tabSize, useSpaces: useSpaces)
            guard removalLength > 0 else { continue }
            removedRanges.append(NSRange(location: lineStart, length: removalLength))
        }

        guard !removedRanges.isEmpty else { return nil }

        var updatedText = text
        for removalRange in removedRanges.sorted(by: { $0.location > $1.location }) {
            guard let stringRange = Range(removalRange, in: updatedText) else {
                return nil
            }
            updatedText.removeSubrange(stringRange)
        }

        let updatedSelection = adjustedSelectionForOutdent(
            original: selection,
            removedRanges: removedRanges
        )

        return OutdentResult(
            replacementRange: NSRange(location: 0, length: nsText.length),
            replacementText: updatedText,
            selectedRange: updatedSelection
        )
    }

    private static func indentString(tabSize: Int, useSpaces: Bool) -> String {
        useSpaces ? String(repeating: " ", count: max(1, tabSize)) : "\t"
    }

    private static func newlineString(in text: String) -> String {
        text.contains("\r\n") ? "\r\n" : "\n"
    }

    private static func lineStarts(in text: String, selection: NSRange) -> [Int] {
        let nsText = text as NSString
        guard nsText.length > 0 else { return [0] }

        let startLineRange = nsText.lineRange(for: NSRange(location: selection.location, length: 0))
        let endLocation = max(selection.location, NSMaxRange(selection) - (selection.length > 0 ? 1 : 0))
        let clampedEnd = min(endLocation, max(0, nsText.length - 1))
        let endLineRange = nsText.lineRange(for: NSRange(location: clampedEnd, length: 0))

        var starts: [Int] = []
        var currentLocation = startLineRange.location
        while currentLocation < NSMaxRange(endLineRange) {
            starts.append(currentLocation)
            let lineRange = nsText.lineRange(for: NSRange(location: currentLocation, length: 0))
            let nextLocation = NSMaxRange(lineRange)
            if nextLocation <= currentLocation {
                break
            }
            currentLocation = nextLocation
        }

        return starts
    }

    private static func utf16StringIndex(in text: String, offset: Int) -> String.Index? {
        guard offset >= 0, offset <= text.utf16.count else { return nil }
        return String.Index(utf16Offset: offset, in: text)
    }

    private static func adjustedSelectionForIndent(
        original: NSRange,
        lineStarts: [Int],
        indentLength: Int
    ) -> NSRange {
        let startsBeforeSelection = lineStarts.filter { $0 < original.location }.count
        let startsWithinSelection = lineStarts.filter { $0 >= original.location && $0 <= NSMaxRange(original) }.count
        let location = original.location + (startsBeforeSelection * indentLength)
        let length = original.length + (startsWithinSelection * indentLength)
        return NSRange(location: location, length: length)
    }

    private static func adjustedSelectionForOutdent(
        original: NSRange,
        removedRanges: [NSRange]
    ) -> NSRange {
        let removedBeforeSelection = removedRanges
            .filter { NSMaxRange($0) <= original.location }
            .reduce(0) { $0 + $1.length }
        let removedInsideSelection = removedRanges
            .filter { $0.location >= original.location && $0.location <= NSMaxRange(original) }
            .reduce(0) { $0 + $1.length }

        let location = max(0, original.location - removedBeforeSelection)
        let length = max(0, original.length - removedInsideSelection)
        return NSRange(location: location, length: length)
    }

    private static func outdentWidth(
        in lineText: String,
        indentUnit: String,
        tabSize: Int,
        useSpaces: Bool
    ) -> Int {
        if useSpaces {
            let leadingSpaces = lineText.prefix(while: { $0 == " " })
            return min((String(leadingSpaces) as NSString).length, max(1, tabSize))
        }

        if lineText.hasPrefix("\t") {
            return 1
        }

        let leadingSpaces = lineText.prefix(while: { $0 == " " })
        return min((String(leadingSpaces) as NSString).length, (indentUnit as NSString).length)
    }
}
