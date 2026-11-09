import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage

/// V4（ZCode）消息列表的 UI 测试夹具。
///
/// - Important: 整个文件置于 `#if DEBUG` 内（项目条件编译规范）。
///   引用它的插件代码必须把**整个函数体**同等包裹在 `#if DEBUG` 内，
///   否则 Release 构建会报「找不到类型」。
///
/// 夹具只在同时带 `--lumi-ui-testing` 与 `--lumi-ui-testing-message-list-zcode`
/// 两个启动参数时生效；缺少 `--lumi-ui-testing` 时**拒绝启动**，
/// 防止 UI 测试误连真实供应商。
#if DEBUG
public enum MessageListZCodeUITestingSupport {

    /// UI 测试是否应注入夹具。
    public static var isEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--lumi-ui-testing") else { return false }
        return arguments.contains("--lumi-ui-testing-message-list-zcode")
    }

    /// 注入 ZCode 夹具会话。
    ///
    /// - Returns: 用于取消的观察句柄；未启用时返回 nil。
    public static func seed(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: (any AgentLoopProviding)?
    ) -> (any ConversationObserverHandle)? {
        guard isEnabled else { return nil }
        return nil
    }
}
#endif
