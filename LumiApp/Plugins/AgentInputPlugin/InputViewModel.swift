import Foundation
import SwiftUI
import Combine

/// 输入框本地状态 ViewModel
///
/// ## 设计目的
/// 将输入框文字状态从 `AgentVM` 中分离，使 `MacEditorView` 的每次击键
/// 只触发订阅了 `InputViewModel` 的视图重渲染，不再广播到整个 `agentProvider`
/// 订阅者树，消除 LLM 流式输出时输入框卡顿的问题。
@MainActor
final class InputViewModel: ObservableObject {
    /// 输入框当前文字
    @Published var text: String = ""
    
    /// 光标位置（用于控制插入后光标位置）
    @Published var cursorPosition: Int = 0

    /// 清空输入框
    func clear() {
        text = ""
        cursorPosition = 0
    }

    /// 追加文字到输入框末尾（用于文件拖放等场景）
    /// 自动将光标移到插入文本之后，并确保末尾有空格
    func append(_ newText: String) {
        // 去除传入文本末尾的空格，我们将自己控制空格
        let trimmedNewText = newText.trimmingCharacters(in: .whitespaces)
        
        // 检查当前文本末尾是否已有空格
        let needsLeadingSpace = !text.isEmpty && !text.hasSuffix(" ")
        let needsTrailingSpace = !trimmedNewText.hasSuffix(" ")
        
        // 构建最终文本
        var finalText = trimmedNewText
        if needsLeadingSpace {
            finalText = " " + finalText
        }
        if needsTrailingSpace {
            finalText = finalText + " "
        }
        
        text += finalText
        // 将光标设置到文本末尾
        cursorPosition = text.count
    }

    /// 设置输入框文字
    func set(_ newText: String) {
        text = newText
        cursorPosition = newText.count
    }

    /// 是否为空（忽略前后空白）
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
