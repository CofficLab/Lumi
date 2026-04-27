import Foundation

// MARK: - Canonical Selection Model
//
// EditorSelectionSet 是编辑器内核的选区 canonical state。
// 它不依赖 NSTextStorage、TextView 或任何原生视图。
//
// 关系：
//   内核选区 (EditorSelectionSet) → canonical state
//   原生选区 (TextView.selectionManager) → 渲染/交互镜像
//
// 同步方向：
//   用户输入 → 原生选区变化 → EditorSelectionMapper.toCanonical → EditorSelectionSet
//   事务应用 → EditorSelectionSet 变化 → EditorSelectionMapper.toView → 原生选区

/// 编辑器内核的选区集合。
///
/// 包含一组有序的选区，第一个为 primary 选区。
/// 所有选区都以 UTF-16 offset 表达，与 EditorRange 体系一致。
struct EditorSelectionSet: Equatable, Sendable {

    /// 选区列表，第一个为 primary。
    let selections: [EditorSelection]

    /// Primary 选区（光标/选区操作的主要目标）。
    var primary: EditorSelection? {
        selections.first
    }

    /// 选区数量。
    var count: Int {
        selections.count
    }

    /// 是否为空。
    var isEmpty: Bool {
        selections.isEmpty
    }

    /// 是否处于多光标模式。
    var isMultiCursor: Bool {
        selections.count > 1
    }

    /// 单光标（无选区）的初始状态。
    static let initial = EditorSelectionSet(selections: [
        EditorSelection(range: EditorRange(location: 0, length: 0))
    ])

    /// 从选区列表创建。空列表会变成初始状态。
    init(selections: [EditorSelection]) {
        if selections.isEmpty {
            self.selections = [EditorSelection(range: EditorRange(location: 0, length: 0))]
        } else {
            self.selections = selections
        }
    }

    /// 替换所有选区。
    func replacingAll(_ newSelections: [EditorSelection]) -> EditorSelectionSet {
        EditorSelectionSet(selections: newSelections)
    }

    /// 替换 primary 选区，保留 secondary。
    func replacingPrimary(_ newPrimary: EditorSelection) -> EditorSelectionSet {
        guard !selections.isEmpty else {
            return EditorSelectionSet(selections: [newPrimary])
        }
        var updated = selections
        updated[0] = newPrimary
        return EditorSelectionSet(selections: updated)
    }

    /// 添加一个选区。
    func addingSelection(_ selection: EditorSelection) -> EditorSelectionSet {
        var updated = selections
        updated.append(selection)
        // 保持按 location 排序
        updated.sort { $0.range.location < $1.range.location }
        return EditorSelectionSet(selections: updated)
    }

    /// 移除最后一个 secondary 选区。
    func removingLastSecondary() -> EditorSelectionSet {
        guard selections.count > 1 else { return self }
        var updated = selections
        updated.removeLast()
        return EditorSelectionSet(selections: updated)
    }

    /// 清除所有 secondary 选区，只保留 primary。
    func clearingSecondary() -> EditorSelectionSet {
        guard let primary else { return .initial }
        return EditorSelectionSet(selections: [primary])
    }
}

// MARK: - Conversion: EditorSelectionSet ↔ MultiCursorSelection

extension EditorSelectionSet {

    /// 从外部 MultiCursorSelection 列表创建。
    init(multiCursorSelections: [MultiCursorSelection]) {
        let mapped = multiCursorSelections
            .filter { $0.location >= 0 }
            .sorted { $0.location < $1.location }
            .map { EditorSelection(range: EditorRange(location: $0.location, length: $0.length)) }
        self.init(selections: mapped)
    }

    /// 转换为外部 MultiCursorSelection 列表。
    func toMultiCursorSelections() -> [MultiCursorSelection] {
        selections.map {
            MultiCursorSelection(location: $0.range.location, length: $0.range.length)
        }
    }

    /// 转换为外部 MultiCursorState。
    func toMultiCursorState() -> MultiCursorState {
        let mcSelections = toMultiCursorSelections()
        return EditorMultiCursorStateController.state(from: mcSelections)
    }
}
