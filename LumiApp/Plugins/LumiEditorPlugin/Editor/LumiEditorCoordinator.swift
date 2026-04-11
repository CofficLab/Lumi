import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView

/// 文本变更协调器
/// 监听 CodeEditSourceEditor 的文本变更，通知 LumiEditorState 触发自动保存
final class LumiEditorCoordinator: TextViewCoordinator {
    
    /// 弱引用状态管理器
    private weak var state: LumiEditorState?
    
    init(state: LumiEditorState) {
        self.state = state
    }
    
    // MARK: - TextViewCoordinator
    
    nonisolated func textViewDidChangeText(controller: TextViewController) {
        let state = self.state
        // 延迟到下一个 RunLoop，避免 "Modifying state during view update"
        DispatchQueue.main.async {
            state?.notifyContentChanged()
        }
    }
    
    nonisolated func prepareCoordinator(controller: TextViewController) {}
    
    nonisolated func destroy() {
        state = nil
    }
}

/// 光标位置协调器
/// 监听光标位置变化，更新行号/列号信息
final class LumiCursorCoordinator: TextViewCoordinator {
    
    private weak var state: LumiEditorState?
    
    init(state: LumiEditorState) {
        self.state = state
    }
    
    // MARK: - TextViewCoordinator
    
    nonisolated func textViewDidChangeSelection(controller: TextViewController) {
        let state = self.state
        let positions = controller.cursorPositions
        var line = 1
        var column = 1
        if let first = positions.first {
            line = first.start.line
            column = first.start.column
        }
        
        // 延迟到下一个 RunLoop，避免 "Modifying state during view update"
        DispatchQueue.main.async {
            state?.cursorLine = line
            state?.cursorColumn = column
        }
    }
    
    nonisolated func prepareCoordinator(controller: TextViewController) {}
    
    nonisolated func controllerDidAppear(controller: TextViewController) {
        if controller.isEditable && controller.isSelectable {
            controller.view.window?.makeFirstResponder(controller.textView)
        }
    }
    
    nonisolated func destroy() {
        state = nil
    }
}
