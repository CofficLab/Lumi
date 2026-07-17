import Foundation

/// 插件在产出贡献（如 `agentTools`）时，所需依赖未就绪的错误。
///
/// 用于替换过去 `guard let dependency = ... else { return [] }` 的静默降级——
/// 依赖缺失通常意味着运行环境异常（核心服务未注册、生命周期未跑完等），应该
/// 抛错让用户在「设置 → 插件」详情页看到，而不是悄悄返回空工具集让 Agent
/// 误以为插件没贡献任何工具。
///
/// 抛出后由 `LumiPluginRegistry` 聚合层捕获并包装成 `LumiPluginContributionFailure`，
/// 最终经 `AgentToolComponent.toolContributionFailures` 暴露给 UI。
public enum LumiPluginDependencyError: LocalizedError {
    /// 某个核心服务未在插件上下文中注册（如 `LumiChatServicing` 缺失）。
    case serviceUnavailable(String)

    /// 插件内部状态未初始化（如 manager 为 nil，通常是 `lifecycle(.didRegister)` 未跑）。
    case stateNotInitialized(String)

    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable(let name):
            return "依赖的服务未就绪：\(name)"
        case .stateNotInitialized(let name):
            return "插件状态未初始化：\(name)"
        }
    }
}
