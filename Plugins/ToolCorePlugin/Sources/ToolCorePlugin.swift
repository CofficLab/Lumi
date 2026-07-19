import Foundation
import LumiCoreKit
import os

/// Tool Core 插件
///
/// 将核心工具集从内核硬编码迁移到插件系统，便于增删与组合。
/// 该插件不可配置且默认启用，确保基础工具始终可用。
public enum ToolCorePlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "ToolCore",
        displayName: LumiPluginLocalization.string("Tool Core", bundle: .module),
        description: LumiPluginLocalization.string("提供 Lumi 的基础工具（文件/命令）。", bundle: .module),
        order: 0,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "wrench.and.screwdriver",
    )

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-core")

    @MainActor
    public static func agentTools(lumiCore: any LumiCoreAccessing) -> [any LumiAgentTool] {
        [
            ListDirectoryTool(),
            ReadFileTool(),
            WriteFileTool(),
            EditFileTool(),
            ShellTool()
        ]
    }
}
