import Foundation
import SwiftUI
import EditorChatInputKit

/// 输入状态（插件内部共享）
@MainActor
final class InputState: ObservableObject {
    /// 当前输入框的文本
    @Published var text: String = ""

    /// 输入框高度（64-300自适应）
    @Published var inputHeight: CGFloat = ChatInputEditorView.minHeight

    /// 输入框是否获得焦点
    @Published var isInputFocused: Bool = false

    /// 光标位置
    @Published var inputCursorPosition: Int = 0

    init() {}
}
