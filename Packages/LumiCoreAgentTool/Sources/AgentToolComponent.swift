import Combine
import Foundation

/// LumiCore 的"AgentTool"功能组件。
///
/// 管理 Agent Tool 相关的状态和逻辑。
@MainActor
public final class AgentToolComponent: ObservableObject {
    public init() {}

    /// 构建本次请求的工具集。
    ///
    /// 收集插件工具、内置工具，构建 per-request `ToolService`。
    /// - Parameters:
    ///   - builtInTools: 内置工具列表
    ///   - pluginTools: 插件提供的工具列表
    ///   - environment: 工具服务环境（可选）
    /// - Returns: 包含工具集的 `ToolService`
    public func buildToolSet(
        builtInTools: [any LumiAgentTool],
        pluginTools: [any LumiAgentTool] = [],
        environment: (any ToolServiceEnvironment)? = nil
    ) -> ToolService {
        // 合并内置工具和插件工具
        let allTools = builtInTools + pluginTools
        return ToolService(tools: allTools, environment: environment)
    }
}