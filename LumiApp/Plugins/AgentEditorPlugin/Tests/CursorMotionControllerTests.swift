#if canImport(XCTest)
import XCTest
@testable import Lumi

final class CursorMotionControllerTests: XCTestCase {

    // MARK: - Character Navigation

    func testMoveLeft() {
        let text = "hello world"
        XCTAssertEqual(
            CursorMotionController.moveLeft(location: 5, text: text).location,
            4
        )
        // 边界：已在开头
        XCTAssertEqual(
            CursorMotionController.moveLeft(location: 0, text: text).location,
            0
        )
    }

    func testMoveRight() {
        let text = "hello world"
        XCTAssertEqual(
            CursorMotionController.moveRight(location: 5, text: text).location,
            6
        )
        // 边界：已在末尾
        let length = text.utf16.count
        XCTAssertEqual(
            CursorMotionController.moveRight(location: length, text: text).location,
            length
        )
    }

    // MARK: - Word Navigation

    func testMoveWordLeft_basic() {
        let text = "hello world"
        // 光标在 "world" 的 'w' 之后，向左应该跳到 'w' 的位置
        XCTAssertEqual(
            CursorMotionController.moveWordLeft(location: 7, text: text).location,
            6  // 'w' 的位置
        )
    }

    func testMoveWordLeft_acrossSpaces() {
        let text = "hello   world"
        // 从 "world" 区域跳过空格到 "hello" 区域
        XCTAssertEqual(
            CursorMotionController.moveWordLeft(location: 9, text: text).location,
            8  // 'w' 的位置
        )
        // 继续向左跳过空格
        XCTAssertEqual(
            CursorMotionController.moveWordLeft(location: 8, text: text).location,
            5  // 第一个空格
        )
        // 继续向左到 "hello" 开头
        XCTAssertEqual(
            CursorMotionController.moveWordLeft(location: 5, text: text).location,
            0
        )
    }

    func testMoveWordLeft_fromMiddleOfWord() {
        let text = "hello"
        // 光标在 'l' 之后，应该跳到行首
        XCTAssertEqual(
            CursorMotionController.moveWordLeft(location: 3, text: text).location,
            0
        )
    }

    func testMoveWordLeft_operators() {
        let text = "foo = bar"
        // 光标在空格之后（'=' 区域），应该跳到 '='
        XCTAssertEqual(
            CursorMotionController.moveWordLeft(location: 4, text: text).location,
            4  // '=' 的位置
        )
    }

    func testMoveWordLeft_atStart() {
        let text = "hello"
        XCTAssertEqual(
            CursorMotionController.moveWordLeft(location: 0, text: text).location,
            0
        )
    }

    func testMoveWordRight_basic() {
        let text = "hello world"
        // 先跳过 'hello' (word)
        XCTAssertEqual(
            CursorMotionController.moveWordRight(location: 0, text: text).location,
            5  // "hello" 之后
        )
        // 继续向右跳过空格到 "world"
        XCTAssertEqual(
            CursorMotionController.moveWordRight(location: 5, text: text).location,
            11  // "world" 之后
        )
    }

    func testMoveWordRight_fromMiddleOfWord() {
        let text = "hello"
        // 从 'l' 向右应该跳到单词末尾
        XCTAssertEqual(
            CursorMotionController.moveWordRight(location: 2, text: text).location,
            5
        )
    }

    func testMoveWordRight_operators() {
        let text = "a + b"
        // 从 'a' 之后应该跳到空格
        XCTAssertEqual(
            CursorMotionController.moveWordRight(location: 0, text: text).location,
            1  // 'a' 之后
        )
        // 跳过空格到 '+'
        XCTAssertEqual(
            CursorMotionController.moveWordRight(location: 1, text: text).location,
            2  // '+' 位置
        )
        // 从 '+' 跳到后面的空格
        XCTAssertEqual(
            CursorMotionController.moveWordRight(location: 2, text: text).location,
            3  // '+' 之后
        )
    }

    func testMoveWordRight_atEnd() {
        let text = "hello"
        let length = text.utf16.count
        XCTAssertEqual(
            CursorMotionController.moveWordRight(location: length, text: text).location,
            length
        )
    }

    // MARK: - Word Deletion

    func testDeleteWordLeft() {
        let text = "hello world"
        let result = CursorMotionController.deleteWordLeft(location: 11, text: text)
        XCTAssertEqual(result.location, 6)
        XCTAssertEqual(result.selectionRange, NSRange(location: 6, length: 5))
    }

    func testDeleteWordRight() {
        let text = "hello world"
        let result = CursorMotionController.deleteWordRight(location: 0, text: text)
        XCTAssertEqual(result.location, 0)
        XCTAssertEqual(result.selectionRange, NSRange(location: 0, length: 5))
    }

    // MARK: - Line Boundary

    func testMoveToBeginningOfLine() {
        let text = "line1\nline2\nline3"
        // 光标在 "line2" 中间，应该跳到 "line2" 的开头
        XCTAssertEqual(
            CursorMotionController.moveToBeginningOfLine(location: 8, text: text).location,
            6
        )
    }

    func testMoveToBeginningOfLine_firstLine() {
        let text = "hello world"
        XCTAssertEqual(
            CursorMotionController.moveToBeginningOfLine(location: 5, text: text).location,
            0
        )
    }

    func testMoveToEndOfLine() {
        let text = "line1\nline2\nline3"
        // 光标在 "line2" 开头，应该跳到 "line2" 的末尾（换行符前）
        XCTAssertEqual(
            CursorMotionController.moveToEndOfLine(location: 6, text: text).location,
            11  // "line2" 之后，换行符之前
        )
    }

    func testMoveToEndOfLine_lastLine() {
        let text = "hello world"
        XCTAssertEqual(
            CursorMotionController.moveToEndOfLine(location: 0, text: text).location,
            11
        )
    }

    // MARK: - Smart Home

    func testSmartHome_fromCodeToIndent() {
        let text = "    hello world"
        // 光标在 "hello" 的 'e' 之后，应该跳到行首 (0)
        let result = CursorMotionController.smartHome(location: 8, text: text)
        XCTAssertEqual(result.location, 0)
    }

    func testSmartHome_fromIndentToCode() {
        let text = "    hello world"
        // 光标在行首 (0)，应该跳到第一个非空白字符 (4)
        let result = CursorMotionController.smartHome(location: 0, text: text)
        XCTAssertEqual(result.location, 4)
    }

    func testSmartHome_toggle() {
        let text = "    hello world"
        // 从代码区域跳到行首
        let step1 = CursorMotionController.smartHome(location: 8, text: text)
        XCTAssertEqual(step1.location, 0)

        // 从行首跳到内容起始
        let step2 = CursorMotionController.smartHome(location: 0, text: text)
        XCTAssertEqual(step2.location, 4)

        // 从内容起始跳回行首
        let step3 = CursorMotionController.smartHome(location: 4, text: text)
        XCTAssertEqual(step3.location, 0)
    }

    func testSmartHome_noIndent() {
        let text = "hello world"
        // 没有缩进的行，Home 直接跳到行首
        let result = CursorMotionController.smartHome(location: 5, text: text)
        XCTAssertEqual(result.location, 0)
    }

    func testSmartHome_emptyLine() {
        let text = "\n"
        let result = CursorMotionController.smartHome(location: 0, text: text)
        XCTAssertEqual(result.location, 0)
    }

    func testSmartHome_middleOfIndent() {
        let text = "    hello"
        // 光标在缩进中间（位置 2），应该跳到内容起始（位置 4）
        let result = CursorMotionController.smartHome(location: 2, text: text)
        XCTAssertEqual(result.location, 4)
    }

    // MARK: - Line Navigation

    func testMoveUp_basic() {
        let text = "line1\nline2\nline3"
        // 光标在 "line2" 开头，上移应该到 "line1" 开头
        XCTAssertEqual(
            CursorMotionController.moveUp(location: 6, text: text, desiredColumn: nil).location,
            0
        )
    }

    func testMoveUp_withColumn() {
        let text = "longline1\nab\nc"
        let result = CursorMotionController.moveUp(location: 12, text: text, desiredColumn: nil)
        XCTAssertEqual(result.location, 2)
    }

    func testMoveUp_preservesDesiredColumn() {
        let text = "abcde\nab\n"
        // 从第 2 行（"ab"），位置在 "ab" 末尾（位置 8 = 6 + 2），desiredColumn = 4
        // 上移到第 1 行，行只有 5 字符，min(4, 5) = 4
        let result = CursorMotionController.moveUp(location: 8, text: text, desiredColumn: 4)
        XCTAssertEqual(result.location, 4)
    }

    func testMoveDown_basic() {
        let text = "line1\nline2\nline3"
        // 光标在 "line1" 开头，下移应该到 "line2" 开头
        XCTAssertEqual(
            CursorMotionController.moveDown(location: 0, text: text, desiredColumn: nil).location,
            6
        )
    }

    func testMoveDown_lastLine() {
        let text = "line1\nline2"
        let length = text.utf16.count
        // 光标在最后一行，下移不应超出
        XCTAssertEqual(
            CursorMotionController.moveDown(location: 8, text: text, desiredColumn: nil).location,
            length
        )
    }

    // MARK: - Document Boundary

    func testMoveToDocumentStart() {
        XCTAssertEqual(CursorMotionController.moveToDocumentStart().location, 0)
    }

    func testMoveToDocumentEnd() {
        let text = "hello"
        XCTAssertEqual(CursorMotionController.moveToDocumentEnd(text: text).location, 5)
    }

    // MARK: - Paragraph Navigation

    func testMoveParagraphBackward_basic() {
        let text = "line1\n\nline3\nline4"
        // 光标在 "line3" 区域，上移一个段落应该到空行位置
        let result = CursorMotionController.moveParagraphBackward(location: 7, text: text)
        XCTAssertEqual(result.location, 6)  // 空行开头
    }

    func testMoveParagraphBackward_fromEmptyLine() {
        let text = "line1\n\nline3"
        // 光标在空行上，跳过空行，到 "line1" 开头
        let result = CursorMotionController.moveParagraphBackward(location: 6, text: text)
        XCTAssertEqual(result.location, 0)
    }

    func testMoveParagraphForward_basic() {
        let text = "line1\n\nline3\nline4"
        // 光标在 "line1" 区域，下移一个段落应该到空行位置
        let result = CursorMotionController.moveParagraphForward(location: 2, text: text)
        XCTAssertEqual(result.location, 6)  // 空行位置
    }

    func testMoveParagraphForward_fromEmptyLine() {
        let text = "line1\n\nline3"
        // 光标在空行上，跳过空行，到 "line3" 开头
        let result = CursorMotionController.moveParagraphForward(location: 6, text: text)
        XCTAssertEqual(result.location, 7)  // "line3" 开头
    }

    func testMoveParagraphBackward_atStart() {
        let text = "hello"
        XCTAssertEqual(
            CursorMotionController.moveParagraphBackward(location: 3, text: text).location,
            0
        )
    }

    func testMoveParagraphForward_atEnd() {
        let text = "hello"
        XCTAssertEqual(
            CursorMotionController.moveParagraphForward(location: 3, text: text).location,
            5
        )
    }

    // MARK: - Edge Cases

    func testEmptyString() {
        let text = ""
        XCTAssertEqual(CursorMotionController.moveWordLeft(location: 0, text: text).location, 0)
        XCTAssertEqual(CursorMotionController.moveWordRight(location: 0, text: text).location, 0)
        XCTAssertEqual(CursorMotionController.moveToBeginningOfLine(location: 0, text: text).location, 0)
        XCTAssertEqual(CursorMotionController.moveToEndOfLine(location: 0, text: text).location, 0)
        XCTAssertEqual(CursorMotionController.smartHome(location: 0, text: text).location, 0)
    }

    func testUnicodeHandling() {
        // 中文文本应该正确处理 UTF-16 offset
        let text = "你好 世界"
        // "你" 是 1 个 UTF-16 code unit
        XCTAssertEqual(CursorMotionController.moveRight(location: 0, text: text).location, 1)
        XCTAssertEqual(CursorMotionController.moveLeft(location: 1, text: text).location, 0)
    }

    func testCRLFHandling() {
        let text = "line1\r\nline2"
        // 行尾应该在 \r\n 之前
        let result = CursorMotionController.moveToEndOfLine(location: 0, text: text)
        XCTAssertEqual(result.location, 5)
    }

    func testMultipleEmptyLines() {
        let text = "a\n\n\n\nb"
        // 从 'b' 向上移动段落，跳过所有空行
        let result = CursorMotionController.moveParagraphBackward(location: 5, text: text)
        XCTAssertEqual(result.location, 0)
    }
}
#endif
