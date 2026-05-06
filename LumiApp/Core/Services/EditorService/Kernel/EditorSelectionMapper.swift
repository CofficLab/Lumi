import AppKit
import CodeEditSourceEditor
import CodeEditTextView
import Foundation

// MARK: - Selection Mapper
//
// EditorSelectionMapper 负责"原生 TextView 选区"与"内核 EditorSelectionSet"之间的转换。
//
// 核心原则：
//   - 用户输入产生原生选区变化 → toCanonical → 更新内核
//   - 事务应用产生内核选区变化 → toView → 更新原生视图
//   - 两个方向互不干扰，避免反馈循环
//
// 对比旧模式：
//   旧：view 改选区 → state 追 → state 回写 → 覆盖 view → 循环
//   新：view → toCanonical → 内核 → 下次 toView 时才写回 view

@MainActor
enum EditorSelectionMapper {

    // MARK: - View → Canonical

    /// 将原生 TextView 的 textSelections 转换为内核 EditorSelectionSet。
    ///
    /// - Parameters:
    ///   - textView: 原生 TextView 实例
    ///   - currentState: 当前的内核选区（用于一致性校验）
    /// - Returns: 转换后的 EditorSelectionSet，如果原生选区无效返回 nil
    static func toCanonical(
        from textView: TextView,
        currentState: EditorSelectionSet
    ) -> EditorSelectionSet? {
        let viewSelections = textView.selectionManager.textSelections
        let canonical = EditorSelectionMappingPolicy.canonicalSelectionSet(
            from: viewSelections.map(\.range)
        )
        guard let canonical else { return nil }
        _ = currentState
        return canonical
    }

    /// 判断是否应该接受这次原生选区变化。
    ///
    /// 在多光标模式下，CodeEditSourceEditor 的 updateCursorPosition() 可能
    /// 会把 textSelections 转换为 cursorPositions 时丢失选区。如果原生
    /// 回传的选区数量少于内核持有的数量，说明发生了丢失，不应该覆盖内核。
    static func shouldAcceptCanonicalUpdate(
        viewSelections: EditorSelectionSet,
        currentState: EditorSelectionSet
    ) -> Bool {
        EditorSelectionMappingPolicy.shouldAcceptCanonicalUpdate(
            viewSelections: viewSelections,
            currentState: currentState
        )
    }

    // MARK: - Canonical → View

    /// 将内核 EditorSelectionSet 应用到原生 TextView。
    ///
    /// 只有在内核选区确实与原生选区不同时才写入，避免不必要的回写。
    static func applyToView(
        _ selectionSet: EditorSelectionSet,
        textView: TextView
    ) {
        let currentViewRanges = textView.selectionManager.textSelections.map(\.range)
        let targetRanges = EditorSelectionMappingPolicy.targetViewRanges(for: selectionSet)

        // 如果一致则跳过，避免触发 selectionDidChange 回调形成循环
        guard !EditorSelectionMappingPolicy.rangesAreEqual(currentViewRanges, targetRanges) else { return }

        textView.selectionManager.setSelectedRanges(targetRanges)
    }
}
