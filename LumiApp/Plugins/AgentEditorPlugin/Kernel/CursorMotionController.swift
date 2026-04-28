import Foundation

// MARK: - Cursor Motion Controller
//
// 后续方向：Cursor motion 语义打磨。
//
// VS Code 级别的光标移动语义包括：
// 1. Word navigation — 单词级移动（moveWordLeft/Right、deleteWordLeft/Right）
// 2. Line boundary — 行首/行尾移动（moveToBeginningOfLine/EndOfLine）
// 3. Smart home — 智能 Home 键（先跳到内容起始，再跳到行首）
// 4. Paragraph navigation — 段落级移动（moveParagraphBackward/Forward）
//
// 所有方法均为纯函数，接受当前文本 + 光标位置，返回目标位置。
// 不直接操作任何 UI 或状态对象。

/// 光标移动目标
struct CursorMotionTarget: Equatable, Sendable {
    /// 目标光标位置（UTF-16 offset）
    let location: Int
    /// 目标选区（如果移动产生了选区扩展，如 shift+move）
    let selectionRange: NSRange?

    init(location: Int, selectionRange: NSRange? = nil) {
        self.location = location
        self.selectionRange = selectionRange
    }
}

/// 光标移动控制器
///
/// 提供与 VS Code 对齐的光标移动语义。
/// 所有方法都是纯函数，不持有状态。
enum CursorMotionController: Sendable {

    // MARK: - Character Navigation

    /// 向左移动一个字符
    static func moveLeft(location: Int, text: String) -> CursorMotionTarget {
        let target = max(0, location - 1)
        return CursorMotionTarget(location: target)
    }

    /// 向右移动一个字符
    static func moveRight(location: Int, text: String) -> CursorMotionTarget {
        let length = (text as NSString).length
        let target = min(length, location + 1)
        return CursorMotionTarget(location: target)
    }

    // MARK: - Word Navigation

    /// 向左移动一个单词（VS Code `cursorWordLeft`）
    ///
    /// 语义：
    /// 1. 跳过当前位置的空白
    /// 2. 跳过当前位置的标点/运算符
    /// 3. 跳过当前位置的单词字符
    /// 4. 如果前面还有空白，继续跳过
    ///
    /// VS Code 的 word boundary 定义与 Apple 的 `CFStringTokenizer` 不同：
    /// VS Code 更接近"空格 + 标点 + 标识符"三段式分割。
    static func moveWordLeft(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let length = nsText.length
        guard location > 0, length > 0 else {
            return CursorMotionTarget(location: 0)
        }

        var pos = location

        // Phase 1: 跳过左侧空白
        while pos > 0, isWhitespace(nsText.character(at: pos - 1)) {
            pos -= 1
        }

        guard pos > 0 else {
            return CursorMotionTarget(location: 0)
        }

        // Phase 2: 根据当前字符类型确定 word boundary
        let charType = characterType(nsText.character(at: pos - 1))

        // Phase 3: 跳过同类型字符
        while pos > 0, characterType(nsText.character(at: pos - 1)) == charType {
            pos -= 1
        }

        return CursorMotionTarget(location: pos)
    }

    /// 向右移动一个单词（VS Code `cursorWordRight`）
    static func moveWordRight(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let length = nsText.length
        guard location < length, length > 0 else {
            return CursorMotionTarget(location: length)
        }

        var pos = location

        // Phase 1: 跳过右侧空白
        while pos < length, isWhitespace(nsText.character(at: pos)) {
            pos += 1
        }

        guard pos < length else {
            return CursorMotionTarget(location: length)
        }

        // Phase 2: 根据当前字符类型确定 word boundary
        let charType = characterType(nsText.character(at: pos))

        // Phase 3: 跳过同类型字符
        while pos < length, characterType(nsText.character(at: pos)) == charType {
            pos += 1
        }

        return CursorMotionTarget(location: pos)
    }

    // MARK: - Word Deletion

    /// 向左删除一个单词（VS Code `deleteWordLeft`）
    ///
    /// 返回删除范围的起止位置。调用者需要删除 [result.location, originalLocation) 范围的文本。
    static func deleteWordLeft(location: Int, text: String) -> CursorMotionTarget {
        let target = moveWordLeft(location: location, text: text)
        return CursorMotionTarget(
            location: target.location,
            selectionRange: NSRange(location: target.location, length: location - target.location)
        )
    }

    /// 向右删除一个单词（VS Code `deleteWordRight`）
    ///
    /// 返回删除范围的起止位置。调用者需要删除 [originalLocation, result.location) 范围的文本。
    static func deleteWordRight(location: Int, text: String) -> CursorMotionTarget {
        let target = moveWordRight(location: location, text: text)
        return CursorMotionTarget(
            location: location,
            selectionRange: NSRange(location: location, length: target.location - location)
        )
    }

    // MARK: - Line Boundary Navigation

    /// 移动到行首（VS Code `cursorHome`）
    ///
    /// 标准 Home 行为：直接跳到行首。
    static func moveToBeginningOfLine(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let lineRange = nsText.lineRange(for: NSRange(location: min(location, nsText.length), length: 0))
        return CursorMotionTarget(location: lineRange.location)
    }

    /// 移动到行尾（VS Code `cursorEnd`）
    static func moveToEndOfLine(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let textLength = nsText.length
        let safeLocation = min(location, textLength)
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
        // lineRange 末尾包含换行符，光标应该放在换行符前
        let lineEnd = NSMaxRange(lineRange)
        let target: Int
        if lineEnd > 0, lineEnd <= textLength {
            // 检查行末是否是换行符
            if lineEnd > lineRange.location,
               nsText.character(at: lineEnd - 1) == UInt16(("\n" as Character).utf16.first!) {
                target = lineEnd - 1
            } else if lineEnd > lineRange.location + 1,
                      nsText.character(at: lineEnd - 2) == UInt16(("\r" as Character).utf16.first!),
                      nsText.character(at: lineEnd - 1) == UInt16(("\n" as Character).utf16.first!) {
                target = lineEnd - 2
            } else {
                target = lineEnd
            }
        } else {
            target = lineEnd
        }
        return CursorMotionTarget(location: target)
    }

    // MARK: - Smart Home

    /// 智能 Home（VS Code `cursorHome` + smart home）
    ///
    /// 行为：
    /// 1. 如果光标在行首（offset 0），不移动
    /// 2. 如果光标在缩进后（第一个非空白字符位置），跳到行首
    /// 3. 如果光标在行首和缩进后之间，跳到缩进后
    /// 4. 如果光标在缩进后之后（代码区域），跳到缩进后
    ///
    /// 总结：在 行首 ↔ 内容起始 之间交替。
    static func smartHome(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let textLength = nsText.length
        let safeLocation = min(location, textLength)
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
        let lineStart = lineRange.location

        // 计算行首非空白字符位置
        let firstNonWhitespace = firstNonWhitespaceOffset(
            in: nsText,
            lineStart: lineStart,
            lineEnd: NSMaxRange(lineRange)
        )

        let lineHome = lineStart
        let contentHome = lineStart + firstNonWhitespace

        // 如果行首和内容起始相同（空行或没有缩进），直接去行首
        if lineHome == contentHome {
            return CursorMotionTarget(location: lineHome)
        }

        // 如果光标已经在行首，跳到内容起始
        if safeLocation <= lineHome {
            return CursorMotionTarget(location: contentHome)
        }

        // 如果光标已经在内容起始或之后，跳到行首
        if safeLocation >= contentHome {
            return CursorMotionTarget(location: lineHome)
        }

        // 光标在缩进中间，跳到内容起始
        return CursorMotionTarget(location: contentHome)
    }

    // MARK: - Line Navigation

    /// 上移一行
    ///
    /// 保持当前列位置（如果新行不够长，则移到行尾）。
    static func moveUp(location: Int, text: String, desiredColumn: Int?) -> CursorMotionTarget {
        let nsText = text as NSString
        let textLength = nsText.length
        let safeLocation = min(location, textLength)
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))

        guard lineRange.location > 0 else {
            return CursorMotionTarget(location: 0)
        }

        // 上一行
        let prevLineEnd = lineRange.location - 1  // 减去换行符
        let prevLineRange = nsText.lineRange(for: NSRange(location: max(0, prevLineEnd), length: 0))

        // 计算列位置
        let column = desiredColumn ?? (safeLocation - lineRange.location)
        let prevLineLength = lineContentLength(nsText, lineRange: prevLineRange)
        let targetColumn = min(column, prevLineLength)
        let target = prevLineRange.location + targetColumn

        return CursorMotionTarget(location: target)
    }

    /// 下移一行
    static func moveDown(location: Int, text: String, desiredColumn: Int?) -> CursorMotionTarget {
        let nsText = text as NSString
        let textLength = nsText.length
        let safeLocation = min(location, textLength)
        let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
        let lineEnd = NSMaxRange(lineRange)

        guard lineEnd < textLength else {
            return CursorMotionTarget(location: textLength)
        }

        // 下一行
        let nextLineRange = nsText.lineRange(for: NSRange(location: lineEnd, length: 0))

        // 计算列位置
        let column = desiredColumn ?? (safeLocation - lineRange.location)
        let nextLineLength = lineContentLength(nsText, lineRange: nextLineRange)
        let targetColumn = min(column, nextLineLength)
        let target = nextLineRange.location + targetColumn

        return CursorMotionTarget(location: target)
    }

    // MARK: - Document Boundary

    /// 移动到文档开头
    static func moveToDocumentStart() -> CursorMotionTarget {
        CursorMotionTarget(location: 0)
    }

    /// 移动到文档末尾
    static func moveToDocumentEnd(text: String) -> CursorMotionTarget {
        CursorMotionTarget(location: (text as NSString).length)
    }

    // MARK: - Paragraph Navigation

    /// 向上移动一个段落（到上一个空行）
    static func moveParagraphBackward(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let textLength = nsText.length
        guard textLength > 0 else { return CursorMotionTarget(location: 0) }

        var pos = min(location, textLength)

        // 如果当前在空行上，先跳过连续空行
        while pos > 0 && isLineEmpty(nsText, at: pos - 1) {
            let lineRange = nsText.lineRange(for: NSRange(location: pos - 1, length: 0))
            pos = lineRange.location
            if pos == 0 { return CursorMotionTarget(location: 0) }
        }

        // 跳过非空行
        while pos > 0 {
            let lineRange = nsText.lineRange(for: NSRange(location: pos - 1, length: 0))
            if isLineEmpty(nsText, at: lineRange.location) {
                return CursorMotionTarget(location: lineRange.location)
            }
            pos = lineRange.location
        }

        return CursorMotionTarget(location: 0)
    }

    /// 向下移动一个段落（到下一个空行）
    static func moveParagraphForward(location: Int, text: String) -> CursorMotionTarget {
        let nsText = text as NSString
        let textLength = nsText.length
        guard textLength > 0 else { return CursorMotionTarget(location: textLength) }

        var pos = min(location, textLength)

        // 如果当前在空行上，先跳过连续空行
        while pos < textLength && isLineEmpty(nsText, at: pos) {
            let lineRange = nsText.lineRange(for: NSRange(location: pos, length: 0))
            let nextPos = NSMaxRange(lineRange)
            if nextPos >= textLength { return CursorMotionTarget(location: textLength) }
            pos = nextPos
        }

        // 跳过非空行
        while pos < textLength {
            let lineRange = nsText.lineRange(for: NSRange(location: pos, length: 0))
            let nextPos = NSMaxRange(lineRange)
            if nextPos >= textLength { return CursorMotionTarget(location: textLength) }
            if isLineEmpty(nsText, at: nextPos) {
                return CursorMotionTarget(location: nextPos)
            }
            pos = nextPos
        }

        return CursorMotionTarget(location: textLength)
    }

    // MARK: - Private Helpers

    /// 字符分类（VS Code 风格）
    ///
    /// VS Code 将字符分为三类来定义 word boundary：
    /// - word: 字母、数字、下划线
    /// - separator: 空白字符
    /// - operator: 标点、运算符等
    private enum CharCategory: Equatable, Sendable {
        case word       // [a-zA-Z0-9_]
        case separator  // 空白
        case operator_  // 标点/运算符
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
        // Space, Tab, Newline, Carriage return, Form feed
        char == 0x20 || char == 0x09 || char == 0x0A || char == 0x0D || char == 0x0C
    }

    private static func isWordCharacter(_ char: UInt16) -> Bool {
        // a-z, A-Z, 0-9, _
        (char >= 0x30 && char <= 0x39) ||  // 0-9
        (char >= 0x41 && char <= 0x5A) ||  // A-Z
        (char >= 0x61 && char <= 0x7A) ||  // a-z
        char == 0x5F                          // _
    }

    /// 计算行内第一个非空白字符的偏移量
    private static func firstNonWhitespaceOffset(
        in nsText: NSString,
        lineStart: Int,
        lineEnd: Int
    ) -> Int {
        var offset = 0
        var pos = lineStart
        while pos < lineEnd {
            let char = nsText.character(at: pos)
            if char != 0x20 && char != 0x09 {  // 不是空格或 Tab
                return offset
            }
            offset += 1
            pos += 1
        }
        return offset
    }

    /// 计算行的内容长度（不含换行符）
    private static func lineContentLength(_ nsText: NSString, lineRange: NSRange) -> Int {
        var length = lineRange.length
        if length > 0 && nsText.character(at: NSMaxRange(lineRange) - 1) == 0x0A {
            length -= 1
            // 检查 \r\n
            if length > 0 && nsText.character(at: NSMaxRange(lineRange) - 2) == 0x0D {
                length -= 1
            }
        }
        return length
    }

    /// 检查指定位置所在的行是否为空行（只包含空白字符或换行符）
    private static func isLineEmpty(_ nsText: NSString, at position: Int) -> Bool {
        guard position >= 0, position < nsText.length else { return true }
        let lineRange = nsText.lineRange(for: NSRange(location: position, length: 0))
        if lineRange.length == 0 { return true }
        // 检查行内容是否只有空白
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
}
