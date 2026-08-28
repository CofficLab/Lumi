import Foundation

/// 命令能力（契约 V2，见重构方案 §8.6）。
///
/// 所有菜单、Toolbar、右键菜单、快捷键和 Agent 编辑操作最终调用命令或事务，
/// 不直接调用某个 ViewModel。
@MainActor
public protocol EditorCommandProviding: AnyObject {
    /// 执行命令。
    ///
    /// - Throws: `EditorContractError.capabilityUnavailable` 命令不存在或当前不可用。
    func execute(_ id: EditorCommandID, arguments: [EditorCommandArgument]) async throws

    /// 按查询过滤命令并返回展示信息（命令面板使用）。
    func presentation(matching query: String, context: EditorCommandContext) -> EditorCommandPresentation

    /// 查询命令在给定上下文下生效的快捷键。
    func keybinding(for commandID: EditorCommandID, context: EditorCommandContext) -> EditorKeybinding?
}

public extension EditorCommandProviding {
    /// 无参数执行命令的便捷入口。
    func execute(_ id: EditorCommandID) async throws {
        try await execute(id, arguments: [])
    }
}
