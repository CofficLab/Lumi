import Foundation

// MARK: - EditorCursorState Compatibility Alias
//
// 路线图早期规划里，光标/选区 canonical state 预期会独立命名为 EditorCursorState。
// 当前实现已经稳定收敛到 EditorSelectionSet：
//
//   - primary / secondary 选区
//   - 多光标判断
//   - 选区增删改
//   - TextView <-> canonical bridge
//
// 为了保留原规划中的模块边界名称，同时不再引入第二套重复状态模型，
// 这里将 EditorCursorState 明确落成对 EditorSelectionSet 的兼容别名。

typealias EditorCursorState = EditorSelectionSet
