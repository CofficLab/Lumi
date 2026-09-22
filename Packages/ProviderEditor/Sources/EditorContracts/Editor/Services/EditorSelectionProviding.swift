import Combine
import Foundation

/// 选择能力（契约 V2，见重构方案 §8.4）。
///
/// 选择是高频状态：本服务不转发 Kernel 全局 `objectWillChange`，
/// 只有编辑器相关视图直接订阅 `statePublisher`。
@MainActor
public protocol EditorSelectionProviding: AnyObject {
    /// 当前选择快照。
    var snapshot: EditorSelectionSnapshot { get }

    /// 选择状态流（CurrentValue 语义）。
    var statePublisher: AnyPublisher<EditorSelectionSnapshot, Never> { get }

    /// 设置全部选择（多光标），并按策略滚动 reveal。
    func setSelections(_ selections: [EditorSelection], reveal: EditorRevealPolicy)

    /// 当前主选择的选中文本（无选择时为 nil）。
    func selectedText() async -> String?

    /// 在指定位置追加一个光标。
    func addCursor(at position: EditorPosition)

    /// 把下一个匹配项加入选择（⌘D 语义）。
    func addNextOccurrence()

    /// 选择全部匹配项。
    func addAllOccurrences()

    /// 清除次级光标，仅保留主选择。
    func clearSecondaryCursors()
}
