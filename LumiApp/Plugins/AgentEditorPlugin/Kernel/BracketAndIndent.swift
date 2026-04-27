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
        let indent = indentString(tabSize: tabSize, useSpaces: useSpaces)

        // 获取当前行
        let lineStart = findLineStart(text, position: position)
        let currentLineEnd = findLineEnd(text, position: position)
        let currentLine = String(text[text.index(text.startIndex, offsetBy: lineStart)..<text.index(text.startIndex, offsetBy: currentLineEnd)])

        // 计算当前行前导空白
        let leadingWhitespace = currentLine.prefix(while: { $0 == " " || $0 == "\t" })

        // 检查光标前一个字符是否是开括号
        let prevChar = position > 0 ? text[text.index(text.startIndex, offsetBy: position - 1)] : nil
        let nextChar = position < text.count ? text[text.index(text.startIndex, offsetBy: position)] : nil

        // 如果光标在 `{` 和 `}` 之间，插入额外的缩进
        if prevChar == "{", nextChar == "}" {
            let newText = "\n" + String(leadingWhitespace) + indent + "\n" + String(leadingWhitespace)
            return IndentResult(
                textToInsert: newText,
                cursorOffset: String(leadingWhitespace).count + indent.count + 1
            )
        }

        // 如果光标前一个字符是开括号，增加缩进
        if let prev = prevChar, prev == "{" || prev == "(" || prev == "[" {
            let newText = "\n" + String(leadingWhitespace) + indent
            return IndentResult(
                textToInsert: newText,
                cursorOffset: String(leadingWhitespace).count + indent.count + 1
            )
        }

        // 默认：保持当前缩进
        let newText = "\n" + String(leadingWhitespace)
        return IndentResult(
            textToInsert: newText,
            cursorOffset: String(leadingWhitespace).count + 1
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

    // MARK: - Private

    private static func indentString(tabSize: Int, useSpaces: Bool) -> String {
        if useSpaces {
            return String(repeating: " ", count: tabSize)
        } else {
            return "\t"
        }
    }

    private static func findLineStart(_ text: String, position: Int) -> Int {
        var pos = position
        while pos > 0 {
            let charIndex = text.index(text.startIndex, offsetBy: pos)
            if text[charIndex] == "\n" {
                return pos + 1
            }
            pos -= 1
        }
        return 0
    }

    private static func findLineEnd(_ text: String, position: Int) -> Int {
        var pos = position
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
