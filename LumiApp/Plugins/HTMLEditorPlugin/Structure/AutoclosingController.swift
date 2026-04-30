import Foundation
import CodeEditSourceEditor
import CodeEditTextView
import AppKit

/// HTML 自动闭合控制器
///
/// 监听文本变化，当用户输入 `>` 时自动补全闭标签。
/// 对自闭合（void）标签如 `<br>`、`<img>` 不生成闭标签。
@MainActor
final class HTMLAutoclosingController: EditorInteractionContributor {
    let id = "builtin.html.autoclosing"

    func onTextDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async {
        guard HTMLKnowledgeBase.isSupported(languageId: context.languageId) else { return }
        guard let typedCharacter = context.typedCharacter, typedCharacter == ">" else { return }

        guard let textView = controller.textView else { return }
        let fullText = textView.string

        // 通过行号和列号计算光标的绝对偏移量
        let cursorOffset = offsetFor(line: context.line, character: context.character, in: fullText)
        guard cursorOffset > 0 else { return }

        // 获取光标前的文本，查找最近的开标签
        let textBefore = String(fullText.prefix(cursorOffset))

        // 检查是否是 `</` 或 `/>` 结尾，跳过
        if textBefore.hasSuffix("</") || textBefore.hasSuffix("/>") { return }

        // 提取最近的开标签名
        guard let tagName = extractOpenTagName(from: textBefore) else { return }

        // 自闭合标签不补全
        guard !HTMLKnowledgeBase.voidElements.contains(tagName) else { return }

        // 在光标后插入闭标签
        let closingTag = "</\(tagName)>"
        textView.replaceCharacters(
            in: NSRange(location: cursorOffset, length: 0),
            with: closingTag
        )
    }

    // MARK: - 私有方法

    /// 计算指定行列在文本中的 UTF-16 偏移量
    private func offsetFor(line: Int, character: Int, in text: String) -> Int {
        var currentLine = 0
        var offset = 0

        for scalar in text.unicodeScalars {
            if currentLine == line {
                return offset + min(character, text.utf16.count - offset)
            }
            offset += scalar.utf16.count
            if scalar == "\n" {
                currentLine += 1
            }
        }

        // 如果行号等于总行数（最后一行之后）
        if currentLine == line {
            return offset + min(character, text.utf16.count - offset)
        }

        return offset
    }

    /// 从文本中提取最后一个未闭合的开标签名
    private func extractOpenTagName(from text: String) -> String? {
        // 向前找 `<`
        var i = text.endIndex
        while i > text.startIndex {
            i = text.index(before: i)
            let char = text[i]

            if char == ">" {
                // 遇到 > 说明在另一个标签内，停止
                return nil
            }

            if char == "<" {
                // 找到开标签起始位置
                let start = text.index(after: i)
                var end = start
                while end < text.endIndex {
                    let c = text[end]
                    if c.isWhitespace || c == ">" || c == "/" { break }
                    end = text.index(after: end)
                }

                let name = String(text[start..<end]).lowercased()
                // 排除闭标签前缀
                if name.hasPrefix("/") { return nil }
                return name.isEmpty ? nil : name
            }
        }

        return nil
    }
}
