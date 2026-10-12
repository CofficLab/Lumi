import Foundation
import KitMCP

/// 其他插件贡献 MCP 服务器配置的入口。
///
/// PluginMCP 在启动时实现此协议并注册到 Kernel；其他插件（如 PluginXcodeMCP）
/// 在 `onBoot` 时解析此 provider，调用 `contribute(_:)` 提供一个内置服务器模板。
/// PluginMCP 收到贡献后将其 seed 到本地注册表（禁用态，用户在设置里启用）。
///
/// - Note: 此协议由 PluginMCP 实现，插件侧只负责调用 `contribute(_:)`。
@MainActor
public protocol MCPServerContributionProviding: AnyObject, Sendable {
    /// 贡献一个 MCP 服务器模板（用户可在设置里编辑、启用或删除）。
    func contribute(_ server: MCPServerConfig)
}
