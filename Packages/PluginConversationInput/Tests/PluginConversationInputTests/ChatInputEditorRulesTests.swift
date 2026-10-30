import AppKit
import Foundation
import Testing
@testable import PluginConversationInput

/// `ChatInputEditorRules` 的索引换算与拖放解析。
///
/// 这两组是编辑器里最容易在重构中被改坏、又最难靠肉眼发现的部分：
///
/// 1. **UTF-16 ⇄ Swift 索引换算**：`NSTextView.selectedRange().location` 是
///    UTF-16 偏移，而 `String.Index` 按 grapheme 计数。两套坐标系一旦搞混，
///    光标就会在 emoji 前后错位——表现为「在表情后面打字，光标跳到别处」。
///    代理表情（ZWJ 序列、肤色修饰符）是这条规则的真正考验。
/// 2. **拖放字符串解析**：从 Finder / 编辑器拖进来的是**纯文本**，不是 URL 对象。
///    `URL(string:)` 对这些字符串的行为反直觉（见各用例注释），解析顺序
///    一旦调整就会静默丢路径。
@MainActor
@Suite("ChatInputEditorRules")
struct ChatInputEditorRulesTests {

    // MARK: - UTF-16 ⇄ Swift 索引换算

    @Test("ASCII 文本的两种索引等价且越界被夹取")
    func asciiIndicesRoundTripAndClamp() {
        let text = "abc"

        #expect(ChatInputEditorRules.swiftToUTF16Index(0, in: text) == 0)
        #expect(ChatInputEditorRules.swiftToUTF16Index(2, in: text) == 2)
        // 越界上界：夹到末尾。
        #expect(ChatInputEditorRules.swiftToUTF16Index(99, in: text) == 3)
        // 越界下界：夹到开头。
        #expect(ChatInputEditorRules.swiftToUTF16Index(-5, in: text) == 0)

        #expect(ChatInputEditorRules.utf16ToSwiftIndex(0, in: text) == 0)
        #expect(ChatInputEditorRules.utf16ToSwiftIndex(2, in: text) == 2)
        #expect(ChatInputEditorRules.utf16ToSwiftIndex(99, in: text) == 3)
        #expect(ChatInputEditorRules.utf16ToSwiftIndex(-5, in: text) == 0)
    }

    @Test("emoji 的 Swift 索引落在 UTF-16 的代理对中间")
    func emojiSwiftIndexMapsToSurrogateMidpoint() {
        // 😀 是单个 grapheme（Swift count 1）但占 2 个 UTF-16 单元。
        let text = "😀"

        // Swift 索引 1 = 整个 emoji 之后 = UTF-16 偏移 2。
        #expect(ChatInputEditorRules.swiftToUTF16Index(1, in: text) == 2)
        #expect(ChatInputEditorRules.swiftToUTF16Index(0, in: text) == 0)
    }

    @Test("UTF-16 偏移落在代理对中间时回退到最近的合法边界")
    func utf16IndexInsideSurrogatePairFallsBack() {
        let text = "a😀b"  // Swift count 3，UTF-16 count 4

        // 偏移 1 是代理对的**中间**（半个字符），没有对应 grapheme，
        // 必须回退到不越过的最近合法位置（索引 1 = "a" 之后）。
        #expect(ChatInputEditorRules.utf16ToSwiftIndex(1, in: text) == 1)
        // 偏移 2 是 emoji 之后，恰好落在 grapheme 边界上。
        #expect(ChatInputEditorRules.utf16ToSwiftIndex(2, in: text) == 1)
        // 偏移 3 = "b" 之后。
        #expect(ChatInputEditorRules.utf16ToSwiftIndex(3, in: text) == 2)
        // 越界夹取到 UTF-16 末尾（4），恰是合法边界，回到 Swift 索引 3。
        #expect(ChatInputEditorRules.utf16ToSwiftIndex(99, in: text) == 3)
    }

    @Test("两套索引在合法边界上互为逆运算")
    func indicesAreInversesAtGraphemeBoundaries() {
        let text = "a😀b多字节 ✅"

        for swiftIndex in 0...text.count {
            let utf16Index = ChatInputEditorRules.swiftToUTF16Index(swiftIndex, in: text)
            #expect(
                ChatInputEditorRules.utf16ToSwiftIndex(utf16Index, in: text) == swiftIndex,
                "在 grapheme 边界 \(swiftIndex) 上往返换算不一致"
            )
        }
    }

    // MARK: - 回车判定

    @Test("回车键在小键盘与主键区都能识别，带修饰键时不触发发送")
    func returnKeyRecognitionRespectsModifiers() {
        // 36 = 主回车，76 = 小键盘回车，两者都应识别。
        #expect(ChatInputEditorRules.isReturnKey(keyCode: 36, charactersIgnoringModifiers: "\r"))
        #expect(ChatInputEditorRules.isReturnKey(keyCode: 76, charactersIgnoringModifiers: nil))
        #expect(ChatInputEditorRules.isReturnKey(keyCode: 36, charactersIgnoringModifiers: "\n"))
        #expect(!ChatInputEditorRules.isReturnKey(keyCode: 53, charactersIgnoringModifiers: nil))

        // 无修饰键 → 发送。
        #expect(
            ChatInputEditorRules.shouldHandleReturnKey(
                keyCode: 36,
                charactersIgnoringModifiers: "\r",
                modifierFlags: []
            )
        )
        // Shift/Option/Command/Control → 插换行，不发送。
        for flags in [NSEvent.ModifierFlags.shift, .option, .command, .control] {
            #expect(
                !ChatInputEditorRules.shouldHandleReturnKey(
                    keyCode: 36,
                    charactersIgnoringModifiers: "\r",
                    modifierFlags: flags
                ),
                "\(flags) + 回车应插入换行而非发送"
            )
        }
        // 非回车键即使无修饰键也不触发。
        #expect(
            !ChatInputEditorRules.shouldHandleReturnKey(
                keyCode: 53,
                charactersIgnoringModifiers: nil,
                modifierFlags: []
            )
        )
    }

    @Test("插入类命令都被视为回车命令")
    func insertCommandsAreRecognized() {
        #expect(ChatInputEditorRules.isEnterCommand(#selector(NSResponder.insertNewline(_:))))
        #expect(ChatInputEditorRules.isEnterCommand(#selector(NSResponder.insertLineBreak(_:))))
        #expect(ChatInputEditorRules.isEnterCommand(#selector(NSResponder.insertParagraphSeparator(_:))))
        #expect(!ChatInputEditorRules.isEnterCommand(#selector(NSResponder.insertText(_:))))
    }

    // MARK: - 拖放字符串解析

    @Test("绝对路径被解析为文件 URL")
    func absolutePathIsParsedAsFileURL() throws {
        // `URL(string: "/tmp/a.txt")` 返回的 URL **不是** file URL（isFileURL == false），
        // 所以不能走第一分支，必须由后面的 `hasPrefix("/")` 分支兜住。
        let url = try #require(
            ChatInputEditorRules.fileURLs(fromDroppedString: "/tmp/a.txt")
                .first
        )

        #expect(url.isFileURL)
        #expect(url.path == "/tmp/a.txt")
    }

    @Test("file:// URL 被解析并保留百分号编码")
    func fileSchemeURLIsParsed() throws {
        let url = try #require(
            ChatInputEditorRules.fileURLs(fromDroppedString: "file:///tmp/a%20b.txt")
                .first
        )

        #expect(url.path == "/tmp/a b.txt")
    }

    @Test("file://localhost/ 前缀被规范化为本地路径")
    func localhostFileSchemeIsNormalized() throws {
        let url = try #require(
            ChatInputEditorRules.fileURLs(fromDroppedString: "file://localhost/tmp/c.txt")
                .first
        )

        // 第一个分支（`URL(string:)`）就会命中，且 URL 本身已归一化掉 localhost。
        #expect(url.path == "/tmp/c.txt")
    }

    @Test("~ 开头的路径被展开为用户主目录")
    func tildePathIsExpanded() throws {
        let url = try #require(
            ChatInputEditorRules.fileURLs(fromDroppedString: "~/Documents")
                .first
        )

        #expect(url.isFileURL)
        // 展开后不应再以 "~" 开头。
        #expect(!url.path.hasPrefix("~"))
        #expect(url.path == FileManager.default.homeDirectoryForCurrentUser.path + "/Documents")
    }

    @Test("多行路径按行拆成多个 URL")
    func multilinePathsSplitPerLine() {
        let urls = ChatInputEditorRules.fileURLs(
            fromDroppedString: "/tmp/a.txt\n/tmp/b.txt\n/tmp/c.txt"
        )

        #expect(urls.count == 3)
        #expect(urls.map(\.path) == ["/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt"])
    }

    @Test("含前后空白与空行的拖放字符串只产出有效行")
    func multilinePathsTrimAndSkipBlanks() {
        let urls = ChatInputEditorRules.fileURLs(
            fromDroppedString: "  /tmp/a.txt  \n\n   \n/tmp/b.txt  "
        )

        // 纯空白行不应产出 URL。
        #expect(urls.map(\.path) == ["/tmp/a.txt", "/tmp/b.txt"])
    }

    @Test("非路径文本不产出 URL")
    func nonPathTextYieldsNoURL() {
        // 注意：这些字符串 `URL(string:)` 都返回**非 nil**，但 isFileURL 为 false，
        // 所以必须由后续分支全部否决，否则普通文本会被当成路径插入。
        #expect(ChatInputEditorRules.fileURLs(fromDroppedString: "hello world").isEmpty)
        #expect(ChatInputEditorRules.fileURLs(fromDroppedString: "just some notes").isEmpty)
        // 空串与纯空白同样不产出。
        #expect(ChatInputEditorRules.fileURLs(fromDroppedString: "").isEmpty)
        #expect(ChatInputEditorRules.fileURLs(fromDroppedString: "   \n  ").isEmpty)
    }

    @Test("单值入口与多值入口的首个结果一致")
    func singleValueEntryMatchesFirstOfMultiple() {
        let expected = ChatInputEditorRules.fileURLs(fromDroppedString: "/tmp/a.txt").first

        #expect(ChatInputEditorRules.fileURL(fromDroppedString: "/tmp/a.txt") == expected)
        #expect(ChatInputEditorRules.fileURL(fromDroppedString: "not a path") == nil)
    }

    // MARK: - 文件类型判定

    @Test("图片扩展名大小写不敏感，非图片被否决")
    func imageExtensionMatchingIsCaseInsensitive() {
        for ext in ["png", "PNG", "jpg", "jpeg", "heic", "webp", "gif", "tiff", "bmp"] {
            #expect(
                ChatInputEditorRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.\(ext)")),
                "\(ext) 应被识别为聊天图片"
            )
        }

        for ext in ["pdf", "txt", "swift", "json", "mp4"] {
            #expect(
                !ChatInputEditorRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.\(ext)")),
                "\(ext) 不应被识别为聊天图片"
            )
        }
        // 无扩展名同样被否决。
        #expect(!ChatInputEditorRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/noext")))
    }
}
