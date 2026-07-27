import EditorService
import Foundation
import LumiKernel

/// 编辑器右键菜单「添加到对话」贡献器。
///
/// 在编辑器右键菜单的 "Chat" 分组下提供「Add to Chat」：
/// - 有选区时：发送 `文件名:起始行-结束行`（单行则 `文件名:行`）
/// - 无选区时：发送 `文件名:光标所在行`
///
/// 仅发送文件路径与行范围引用，不发送代码正文（更省 token，由 AI 按引用读取文件）。
/// 载荷经 `EditorChatAddToChat` 走 `addToChat` 通知通道，聊天接收端零改动。
@MainActor
public final class EditorChatSelectionCommandContributor: SuperEditorCommandContributor {
    public let id: String = "editorchat.commands"

    public init() {}

    public func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        let reference = Self.makeReference(
            context: context,
            state: state,
            textView: textView
        )

        return [
            EditorCommandSuggestion(
                id: "editorchat.add-to-chat",
                title: LumiPluginLocalization.string("Add to Chat", bundle: .module),
                systemImage: "plus.bubble",
                category: EditorCommandCategory.chat.rawValue,
                order: 100,
                isEnabled: reference != nil
            ) {
                guard let reference else { return }
                EditorChatAddToChat.post(reference, windowId: state.windowId)
            }
        ]
    }

    /// 计算要发送到对话的引用字符串；无法确定文件时返回 nil（菜单项禁用）。
    private static func makeReference(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> String? {
        guard let fileName = state.currentFileURL?.lastPathComponent else { return nil }

        // 优先用选区计算行范围；选区为空时回退到光标所在行（context.line 为 0-based）。
        if let textView,
           let selection = textView.selectionManager.textSelections.first?.range,
           selection.length > 0,
           selection.location != NSNotFound,
           let lines = lineRange(for: selection, in: textView.string) {
            let (startLine, endLine) = lines
            if startLine == endLine {
                return "\(fileName):\(startLine)"
            }
            return "\(fileName):\(startLine)-\(endLine)"
        }

        // context.line 是 0-based，显示用 1-based。
        return "\(fileName):\(context.line + 1)"
    }

    /// 将选区 NSRange 换算成 1-based 的 (起始行, 结束行)。
    ///
    /// 复用 `selectedTextForCodeActions()` 取 range 的写法，行号通过 `\n` 计数得到。
    /// 结束位置若恰好落在某行行首（选区结尾紧跟换行符之后），回退到上一行，
    /// 让行范围对应用户视觉上选中的行。
    private static func lineRange(for range: NSRange, in text: String) -> (Int, Int)? {
        guard let swiftRange = Range(range, in: text) else { return nil }
        let text = Substring(text)
        let startOffset = text.distance(from: text.startIndex, to: swiftRange.lowerBound)
        let endOffset = text.distance(from: text.startIndex, to: swiftRange.upperBound)

        let startLine = lineNumber(at: startOffset, in: text)
        // endOffset 指向选区结尾（开区间），若它正好是某行行首，则结束行应为上一行。
        var endLine = lineNumber(at: endOffset, in: text)
        if endLine > startLine, endOffset > startOffset, isAtLineStart(offset: endOffset, in: text) {
            endLine -= 1
        }
        if endLine < startLine { endLine = startLine }
        return (startLine, endLine)
    }

    /// 返回 1-based 行号：统计 offset 之前的换行符数量 + 1。
    private static func lineNumber(at offset: Int, in text: Substring) -> Int {
        var line = 1
        var consumed = 0
        for char in text {
            if consumed >= offset { break }
            if char == "\n" { line += 1 }
            consumed += 1
        }
        return line
    }

    /// offset 是否恰好位于某一行行首（即 offset==0 或前一字符为 `\n`）。
    private static func isAtLineStart(offset: Int, in text: Substring) -> Bool {
        guard offset > 0 else { return true }
        let index = text.index(text.startIndex, offsetBy: offset)
        let prev = text.index(before: index)
        return text[prev] == "\n"
    }
}
