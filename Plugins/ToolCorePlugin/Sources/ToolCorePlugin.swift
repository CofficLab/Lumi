import Foundation
import LumiCoreKit
import AgentToolKit
import os

/// Tool Core 插件
///
/// 将核心工具集从内核硬编码迁移到插件系统，便于增删与组合。
/// 该插件不可配置且默认启用，确保基础工具始终可用。
public actor ToolCorePlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.tool-core")
    public static let id: String = "ToolCore"
    public static let displayName: String = String(localized: "Tool Core", bundle: .module)
    public static let description: String = String(localized: "提供 Lumi 的基础工具（文件/命令）。", bundle: .module)
    public static let iconName: String = "wrench.and.screwdriver"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 0 }

    public static let shared = ToolCorePlugin()

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        context.toolService.registerProgressSnapshotProvider(for: "run_command") {
            guard let snapshot = await ShellService.shared.progressSnapshot() else {
                return nil
            }
            return ToolProgressSnapshot(
                totalLines: snapshot.totalLines,
                totalBytes: snapshot.totalBytes,
                latestOutputPreview: snapshot.latestOutputPreview
            )
        }

        return [
            ListDirectoryTool(),
            ReadFileTool(),
            WriteFileTool(),
            EditFileTool(),
            ShellTool(),
        ]
    }
}
