import Foundation
import KitMCP
import ProviderMCP

/// PluginMCP 的 MCP 服务器贡献收集器。
///
/// 实现 `MCPServerContributionProviding`，注册到 Kernel 后，其他插件
/// （如 PluginXcodeMCP、PluginGithubMCP）调用 `contribute(_:)` 提供内置服务器模板。
/// 新贡献通过 `onContribute` 同步通知 Registry 落库（不依赖 Observation 时序）。
@MainActor
public final class MCPServerContributor: MCPServerContributionProviding, ObservableObject {
    /// 已收集到的服务器模板（按贡献顺序）。
    @Published public private(set) var contributions: [MCPServerConfig] = []

    /// 新贡献到达时的同步回调（由 Registry 设置，用于即时 seed）。
    public var onContribute: ((MCPServerConfig) -> Void)?

    public init() {}

    public func contribute(_ server: MCPServerConfig) {
        // 去重：同 command + arguments 视为同一服务器。
        guard !contributions.contains(where: {
            $0.command == server.command && $0.arguments == server.arguments
        }) else { return }
        contributions.append(server)
        onContribute?(server)
    }
}
