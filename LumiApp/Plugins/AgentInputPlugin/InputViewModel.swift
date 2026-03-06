import Foundation
import SwiftUI

/// 输入框本地状态 ViewModel
///
/// ## 设计目的
/// 将输入框文字状态从 `AgentProvider` 中分离，使 `MacEditorView` 的每次击键
/// 只触发订阅了 `InputViewModel` 的视图重渲染，不再广播到整个 `agentProvider`
/// 订阅者树，消除 LLM 流式输出时输入框卡顿的问题。
@MainActor
final class InputViewModel: ObservableObject {
    /// 输入框当前文字
    @Published var text: String = ""

    /// 清空输入框
    func clear() {
        text = ""
    }

    /// 追加文字到输入框末尾（用于文件拖放等场景）
    func append(_ newText: String) {
        text += newText
    }

    /// 设置输入框文字
    func set(_ newText: String) {
        text = newText
    }

    /// 是否为空（忽略前后空白）
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
