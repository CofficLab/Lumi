import Foundation

// MARK: - Bracket & Auto-Closing Pairs
//
// Phase 9: 编辑体验打磨 — 括号匹配、自动闭合、自动缩进。
//
// VS Code 的核心编辑体验包括：
// 1. 自动闭合：输入 `(` 自动补 `)`，输入 `[` 自动补 `]`
// 2. 自动环绕：选中文本后输入 `(` 变成 `(选中文本)`
// 3. 括号匹配：光标在括号旁边时，高亮对应的括号
// 4. 自动缩进：换行时保持或增加缩进级别

/// 括号对定义。
struct BracketPair: Hashable, Sendable {
    let open: Character
    let close: Character

    init(open: Character, close: Character) {
        self.open = open
        self.close = close
    }

    func matchesClose(_ char: Character) -> Bool {
        close == char
    }

    func matchesOpen(_ char: Character) -> Bool {
        open == char
    }
}

/// 语言特定的括号对配置。
struct BracketPairsConfig: Sendable {
    let pairs: [BracketPair]
    let autoClosingPairs: [AutoClosingPair]

    /// 创建配置。
    /// - Parameters:
    ///   - pairs: 括号对列表
    ///   - autoClosingPairs: 自动闭合配置（默认为所有括号对）
    init(
        pairs: [BracketPair],
        autoClosingPairs: [AutoClosingPair]? = nil
    ) {
        self.pairs = pairs
        self.autoClosingPairs = autoClosingPairs ?? pairs.map { pair in
            AutoClosingPair(open: pair.open, close: pair.close)
        }
    }

    /// 编程语言的默认括号配置。
    static func defaultForLanguage(_ languageId: String) -> BracketPairsConfig {
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
                autoClosingPairs: []  // HTML/XML 标签不自动闭合
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

    /// 查找给定开括号对应的闭括号。
    func matchingClose(for open: Character) -> Character? {
        pairs.first(where: { $0.open == open })?.close
    }

    /// 查找给定闭括号对应的开括号。
    func matchingOpen(for close: Character) -> Character? {
        pairs.first(where: { $0.close == close })?.open
    }

    /// 检查字符是否是开括号。
    func isOpenBracket(_ char: Character) -> Bool {
        pairs.contains { $0.open == char }
    }

    /// 检查字符是否是闭括号。
    func isCloseBracket(_ char: Character) -> Bool {
        pairs.contains { $0.close == char }
    }
}

/// 自动闭合对配置。
struct AutoClosingPair: Hashable, Sendable {
    let open: Character
    let close: Character
    let notIn: [AutoClosingContext]

    init(open: Character, close: Character, notIn: [AutoClosingContext] = []) {
        self.open = open
        self.close = close
        self.notIn = notIn
    }
}

/// 自动闭合上下文限制。
enum AutoClosingContext: Hashable, Sendable {
    /// 不在字符串内
    case string
    /// 不在注释内
    case comment
    /// 不在正则表达式内
    case regex
}

/// 括号匹配器。
///
/// 给定文本和光标位置，找到匹配的括号对。
enum BracketMatcher {

    struct AutoClosingEdit: Equatable, Sendable {
        let replacementRange: NSRange
        let replacementText: String
        let selectedRange: NSRange
    }

    /// 括号匹配结果。
    struct MatchResult {
        /// 开括号位置。
        let openPosition: Int
        /// 闭括号位置。
        let closePosition: Int
    }

    /// 在给定文本中查找光标位置附近的匹配括号。
    ///
    /// - Parameters:
    ///   - text: 文档文本
    ///   - cursorPosition: 光标位置（UTF-16 offset）
    ///   - config: 括号对配置
    /// - Returns: 如果光标在括号旁边，返回匹配结果
    static func findMatchingBracket(
        in text: String,
        at cursorPosition: Int,
        config: BracketPairsConfig
    ) -> MatchResult? {
        let textLength = text.utf16.count
        guard cursorPosition >= 0, cursorPosition <= textLength else { return nil }

        // 检查光标前一个字符是否是开括号
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

        // 检查光标当前位置字符是否是开括号
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

        // 检查光标位置字符是否是闭括号
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

        // 检查光标前一个字符是否是闭括号
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

    /// 检查字符后是否是自动闭合的候选。
    ///
    /// - Parameters:
    ///   - text: 文档文本
    ///   - position: 输入位置
    ///   - typedChar: 刚输入的字符
    ///   - config: 自动闭合配置
    /// - Returns: 如果需要自动闭合，返回应插入的闭括号字符
    static func shouldAutoClose(
        in text: String,
        at position: Int,
        typedChar: Character,
        config: BracketPairsConfig
    ) -> Character? {
        // 检查是否是自动闭合对中的开括号
        guard let autoPair = config.autoClosingPairs.first(where: { $0.open == typedChar }) else {
            return nil
        }

        // 检查是否在禁止上下文中（字符串、注释等）
        // 简化实现：检查光标前是否有未闭合的引号
        if autoPair.notIn.contains(.string) {
            if isInStringContext(text, position: position) {
                return nil
            }
        }
        if autoPair.notIn.contains(.comment) {
            if isInCommentContext(text, position: position) {
                return nil
            }
        }

        return autoPair.close
    }

    /// 检查是否应该自动环绕选中的文本。
    static func shouldAutoSurround(
        typedChar: Character,
        config: BracketPairsConfig
    ) -> Bool {
        config.pairs.contains { $0.open == typedChar } ||
        config.pairs.contains { $0.close == typedChar }
    }

    static func autoClosingEdit(
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

    // MARK: - Private

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

    /// 简化版字符串上下文检测。
    private static func isInStringContext(_ text: String, position: Int) -> Bool {
        // 统计 position 之前的引号数量
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

    /// 简化版注释上下文检测。
    private static func isInCommentContext(_ text: String, position: Int) -> Bool {
        let prefix = String(text.prefix(position))
        let lines = prefix.components(separatedBy: "\n")
        guard let lastLine = lines.last else { return false }

        return lastLine.contains("//")
    }
}

/// 智能换行/自动缩进处理器。
enum SmartIndentHandler {

    struct IndentResult {
        let textToInsert: String
        let cursorOffset: Int
    }

    struct OutdentResult: Equatable, Sendable {
        let replacementRange: NSRange
        let replacementText: String
        let selectedRange: NSRange
    }

    /// 处理换行时的自动缩进。
    ///
    /// - Parameters:
    ///   - text: 文档文本
    ///   - position: 换行位置
    ///   - tabSize: Tab 宽度
    ///   - useSpaces: 是否使用空格
    /// - Returns: 应插入的文本（换行 + 缩进）和光标偏移
    static func handleEnter(
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

        // 计算当前行前导空白
        let leadingWhitespace = currentLineText.prefix(while: { $0 == " " || $0 == "\t" })
        let leadingWhitespaceLength = (String(leadingWhitespace) as NSString).length
        let indentLength = (indent as NSString).length
        let newlineLength = (newline as NSString).length

        // 检查光标前一个字符是否是开括号
        let prevChar: Character? = safePosition > 0
            ? nsText.substring(with: NSRange(location: safePosition - 1, length: 1)).first
            : nil
        let nextChar: Character? = safePosition < nsText.length
            ? nsText.substring(with: NSRange(location: safePosition, length: 1)).first
            : nil

        // 如果光标在 `{` 和 `}` 之间，插入额外的缩进
        if prevChar == "{", nextChar == "}" {
            let newText = newline + String(leadingWhitespace) + indent + newline + String(leadingWhitespace)
            return IndentResult(
                textToInsert: newText,
                cursorOffset: leadingWhitespaceLength + indentLength + newlineLength
            )
        }

        // 如果光标前一个字符是开括号，增加缩进
        if let prev = prevChar, prev == "{" || prev == "(" || prev == "[" {
            let newText = newline + String(leadingWhitespace) + indent
            return IndentResult(
                textToInsert: newText,
                cursorOffset: leadingWhitespaceLength + indentLength + newlineLength
            )
        }

        // 默认：保持当前缩进
        let newText = newline + String(leadingWhitespace)
        return IndentResult(
            textToInsert: newText,
            cursorOffset: leadingWhitespaceLength + newlineLength
        )
    }

    /// 处理 Tab 键。
    static func handleTab(
        at position: Int,
        hasSelection: Bool,
        selectionStart: Int,
        selectionEnd: Int,
        tabSize: Int,
        useSpaces: Bool
    ) -> IndentResult {
        let indent = indentString(tabSize: tabSize, useSpaces: useSpaces)

        if hasSelection {
            // 多行缩进：缩进选中范围的每一行
            return IndentResult(
                textToInsert: indent,
                cursorOffset: indent.count
            )
        } else {
            return IndentResult(
                textToInsert: indent,
                cursorOffset: indent.count
            )
        }
    }

    static func handleTab(
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
            let stringIndex = updatedText.index(updatedText.startIndex, offsetBy: lineStart)
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

    static func handleBacktab(
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
        for range in removedRanges.reversed() {
            let stringRange = Range(range, in: updatedText)!
            updatedText.removeSubrange(stringRange)
        }

        let replacementRange = NSRange(location: 0, length: nsText.length)
        let updatedSelection = adjustedSelection(
            original: selection,
            removedRanges: removedRanges
        )

        return OutdentResult(
            replacementRange: replacementRange,
            replacementText: updatedText,
            selectedRange: updatedSelection
        )
    }

    // MARK: - Private

    private static func indentString(tabSize: Int, useSpaces: Bool) -> String {
        if useSpaces {
            return String(repeating: " ", count: tabSize)
        } else {
            return "\t"
        }
    }

    private static func newlineString(in text: String) -> String {
        if text.contains("\r\n") {
            return "\r\n"
        }
        return "\n"
    }

    private static func lineStarts(in text: String, selection: NSRange) -> [Int] {
        let nsText = text as NSString
        let firstLineStart = nsText.lineRange(for: NSRange(location: selection.location, length: 0)).location
        let lastLocation = selection.length > 0
            ? max(selection.location, NSMaxRange(selection) - 1)
            : selection.location
        let lastLineStart = nsText.lineRange(for: NSRange(location: lastLocation, length: 0)).location

        var starts: [Int] = []
        var current = firstLineStart
        while current <= lastLineStart, current < nsText.length {
            starts.append(current)
            let lineRange = nsText.lineRange(for: NSRange(location: current, length: 0))
            let next = NSMaxRange(lineRange)
            if next <= current { break }
            current = next
        }

        if starts.isEmpty, firstLineStart == nsText.length {
            starts.append(firstLineStart)
        }
        return starts
    }

    private static func outdentWidth(
        in lineText: String,
        indentUnit: String,
        tabSize: Int,
        useSpaces: Bool
    ) -> Int {
        let nsLine = lineText as NSString
        if useSpaces {
            let maxWidth = min(tabSize, nsLine.length)
            var count = 0
            while count < maxWidth, nsLine.character(at: count) == 32 {
                count += 1
            }
            return count
        }

        guard nsLine.length > 0 else { return 0 }
        if nsLine.character(at: 0) == 9 {
            return 1
        }
        let indentLength = (indentUnit as NSString).length
        if indentLength > 0, nsLine.length >= indentLength,
           nsLine.substring(with: NSRange(location: 0, length: indentLength)) == indentUnit {
            return indentLength
        }
        return 0
    }

    private static func adjustedSelection(
        original: NSRange,
        removedRanges: [NSRange]
    ) -> NSRange {
        let originalEnd = NSMaxRange(original)
        let startShift = removedRanges
            .filter { $0.location < original.location }
            .reduce(0) { $0 + $1.length }

        let endShift = removedRanges
            .filter { $0.location < originalEnd }
            .reduce(0) { $0 + $1.length }

        let newLocation = max(0, original.location - startShift)
        let newEnd = max(newLocation, originalEnd - endShift)
        return NSRange(location: newLocation, length: newEnd - newLocation)
    }

    private static func adjustedSelectionForIndent(
        original: NSRange,
        lineStarts: [Int],
        indentLength: Int
    ) -> NSRange {
        let originalEnd = NSMaxRange(original)
        let startShift = lineStarts.filter { $0 < original.location }.count * indentLength
        let endShift = lineStarts.filter { $0 < originalEnd }.count * indentLength
        let newLocation = original.location + startShift
        let newEnd = max(newLocation, originalEnd + endShift)
        return NSRange(location: newLocation, length: newEnd - newLocation)
    }

    private static func findLineStart(_ text: String, position: Int) -> Int {
        var pos = min(max(0, position), text.count)
        while pos > 0 {
            let charIndex = text.index(text.startIndex, offsetBy: pos - 1)
            if text[charIndex] == "\n" {
                return pos
            }
            pos -= 1
        }
        return 0
    }

    private static func findLineEnd(_ text: String, position: Int) -> Int {
        var pos = min(max(0, position), text.count)
        while pos < text.count {
            let charIndex = text.index(text.startIndex, offsetBy: pos)
            if text[charIndex] == "\n" {
                return pos
            }
            pos += 1
        }
        return text.count
    }
}
