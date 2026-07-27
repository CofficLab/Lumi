import LumiKernel

@MainActor
enum GitRuntimeBridge {
    static let gitVM = AppGitVM()

    /// 提供一个"用 LLM 临时生成本次 commit message"的查询入口。
    ///
    /// 由 `LumiFactory` 在 `createKernel()` 末尾完成注入:
    /// 若 `LumiCore` 注册了 `LumiEphemeralChatQuerying` 服务,此闭包非空;
    /// 调用方可直接 `GitRuntimeBridge.chatQueryProvider?()` 拿到,
    /// 不必再依赖体积庞大的 `LumiChatServicing` 接口。
    ///
    /// 设计要点:
    /// - 用窄协议 `LumiEphemeralChatQuerying` 而非 `LumiChatServicing`:
    ///   表明 GitPlugin 仅需要"做一次不写入历史的补全",不需要对话/选中/路由等能力。
    /// - 闭包形式:延迟解析服务指针,允许 chat 服务的具体实现类型被替换后自动跟随。
    static var chatQueryProvider: (@MainActor () -> (any LumiEphemeralChatQuerying)?)?
}
