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

        // 过滤无效选区
        let validRanges = viewSelections
            .map(\.range)
            .filter { $0.location != NSNotFound && $0.location >= 0 }

        guard !validRanges.isEmpty else { return nil }

        let mapped = validRanges
            .sorted { $0.location < $1.location }
            .map { EditorSelection(range: EditorRange(location: $0.location, length: $0.length)) }

        return EditorSelectionSet(selections: mapped)
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
        // 单光标模式总是接受
        if !currentState.isMultiCursor && !viewSelections.isMultiCursor {
            return true
        }

        // 多光标模式下，原生选区数量减少时拒绝（可能是 CodeEdit 内部丢失）
        if currentState.isMultiCursor && viewSelections.count < currentState.count {
            return false
        }

        return true
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

        let targetRanges = selectionSet.selections.map(\.range.nsRange)

        // 如果一致则跳过，避免触发 selectionDidChange 回调形成循环
        guard !rangesAreEqual(currentViewRanges, targetRanges) else { return }

        textView.selectionManager.setSelectedRanges(targetRanges)
    }

    // MARK: - Private

    private static func rangesAreEqual(
        _ lhs: [NSRange],
        _ rhs: [NSRange]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { $0 == $1 }
    }
}
