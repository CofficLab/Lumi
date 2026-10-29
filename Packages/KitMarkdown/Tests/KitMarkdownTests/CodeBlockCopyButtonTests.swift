import Testing
@testable import KitMarkdown

/// 代码块复制按钮的行为断言。
///
/// 不变式：**点击复制按钮必须把该代码块的原文交给复制执行器** ——
/// 复制的是纯代码文本，不是带语法高亮的富文本，也不含 Markdown 围栏。
///
/// 复制执行器通过 `copyHandler` 注入替身，测试进程不写真实剪贴板。
@MainActor
@Suite
struct CodeBlockCopyButtonTests {

    @Test("复制时传递代码原文")
    func copiesRawCode() {
        let code = """
        import Foundation

        func greet() -> String {
            return "hi"
        }
        """
        var captured: String?
        let button = CodeBlockCopyButton(code: code) { value in
            captured = value
        }

        button.performCopy()

        #expect(captured == code)
    }

    @Test("复制内容不含 Markdown 围栏与语言标记")
    func copiesWithoutFence() {
        let code = "let a = 1"
        var captured: String?
        let button = CodeBlockCopyButton(code: code) { value in
            captured = value
        }

        button.performCopy()

        #expect(captured == "let a = 1")
        #expect(captured?.contains("```") == false)
    }

    @Test("多行代码的换行被完整保留")
    func preservesNewlines() {
        let code = "line1\nline2\n\nline4"
        var captured: String?
        let button = CodeBlockCopyButton(code: code) { value in
            captured = value
        }

        button.performCopy()

        #expect(captured == code)
        #expect(captured?.components(separatedBy: "\n").count == 4)
    }
}
