import LumiCoreKit
import AgentToolKit
import SwiftUI
import os

/// MCP 工具插件：将 MCP 封装成内核可见的 AgentTools（用户无需关心安装/管理）。
public enum AgentMCPToolsPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "server.rack"

    public static let info = LumiPluginInfo(
        id: "AgentMCPTools",
        displayName: LumiPluginLocalization.string("MCP Tools", bundle: .module),
        description: LumiPluginLocalization.string("MCP-backed tools (hidden)", bundle: .module),
        order: 60
    )
}

extension Notification.Name {
    public static let toolSourcesDidChange = Notification.Name("toolSourcesDidChange")
}
