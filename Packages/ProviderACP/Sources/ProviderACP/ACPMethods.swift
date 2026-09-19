import Foundation

/// Agent Client Protocol 版本与常量。
///
/// 协议版本是一个整数，标识 **MAJOR** 协议版本，仅在引入破坏性变更时递增。
/// 当前规范版本为 1。
/// 参考：https://agentclientprotocol.com/protocol/initialization
public enum ACPVersion {
    /// 当前实现的协议主版本。
    public static let current = 1
}

/// ACP 方法名常量。
///
/// 与官方 schema 保持一致：方法名使用 snake_case。
/// 参考：https://agentclientprotocol.com/protocol/overview
public enum ACPMethod {
    // MARK: - Agent 端基线方法（Client → Agent）

    /// 建立连接并协商协议版本与能力。
    public static let initialize = "initialize"

    /// 创建新会话。
    public static let sessionNew = "session/new"

    /// 发送用户提示，回合直到返回 StopReason 结束。
    public static let sessionPrompt = "session/prompt"

    // MARK: - Agent 端可选方法（Client → Agent）

    /// 加载既有会话并回放历史（需 `loadSession` 能力）。
    public static let sessionLoad = "session/load"

    /// 恢复既有会话而不回放历史（需 `sessionCapabilities.resume`）。
    public static let sessionResume = "session/resume"

    /// 关闭活跃会话（需 `sessionCapabilities.close`）。
    public static let sessionClose = "session/close"

    /// 切换会话操作模式。
    public static let sessionSetMode = "session/set_mode"

    /// 结束当前认证状态（需 `auth.logout` 能力）。
    public static let logout = "logout"

    // MARK: - 通知

    /// Client → Agent：取消进行中的回合（通知，无响应）。
    public static let sessionCancel = "session/cancel"

    /// Agent → Client：会话更新通知（流式输出、工具调用、计划等）。
    public static let sessionUpdate = "session/update"

    // MARK: - Client 端方法（Agent → Client 调用）

    /// Agent → Client：请求用户授权一次工具调用。
    public static let sessionRequestPermission = "session/request_permission"

    /// Agent → Client：读取文本文件（需 Client `fs.readTextFile` 能力）。
    public static let fsReadTextFile = "fs/read_text_file"

    /// Agent → Client：写入文本文件（需 Client `fs.writeTextFile` 能力）。
    public static let fsWriteTextFile = "fs/write_text_file"
}
