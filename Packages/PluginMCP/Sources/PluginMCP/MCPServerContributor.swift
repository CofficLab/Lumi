import Foundation
import KitMCP
import ProviderMCP

/// PluginMCP 的 MCP 服务器贡献收集器。
///
/// 实现 `MCPServerContributionProviding`，注册到 Kernel 后，其他插件
/// （如 PluginXcodeMCP）调用 `contribute(_:)` 提供内置服务器模板。
/// Registry 通过观察 `contributions` 自动把新贡献 seed 到本地列表。
@MainActor
public final class MCPServerContributor: MCPServerContributionProviding, ObservableObject {
    /// 已收集到的服务器模板（按贡献顺序）。
    @Published public private(set) var contributions: [MCPServerConfig] = []

    public init() {}

    public func contribute(_ server: MCPServerConfig) {
        // 去重：同 command + arguments 视为同一服务器。
        guard !contributions.contains(where: {
            $0.command == server.command && $0.arguments == server.arguments
        }) else { return }
        contributions.append(server)
    }
}
