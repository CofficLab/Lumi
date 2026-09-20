import Foundation

/// 编辑器作用域。
///
/// 见 `docs/editor-kernel-plugin-rearchitecture-plan.md` §8.1：
/// 即使当前只有单窗口，契约也从第一版开始携带作用域，
/// 避免未来用全局单例重构。
public struct EditorScope: Equatable, Hashable, Sendable {
    /// 所属窗口。
    public let windowID: EditorWindowID

    /// 所属工作区。
    public let workspaceID: EditorWorkspaceID

    public init(windowID: EditorWindowID, workspaceID: EditorWorkspaceID) {
        self.windowID = windowID
        self.workspaceID = workspaceID
    }
}
