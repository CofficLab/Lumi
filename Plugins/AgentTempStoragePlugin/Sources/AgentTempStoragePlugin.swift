import Foundation
import LumiCoreKit
import LumiUI
import SwiftUI
import os

/// Agent 临时文件存储插件。
///
/// 为 Agent 提供隔离的临时文件目录，支持写入、读取与列举；
/// 超过保留期限（默认 7 天）的文件会自动清理。
public enum AgentTempStoragePlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-temp-storage")

    public static let info = LumiPluginInfo(
        id: "AgentTempStorage",
        displayName: PluginAgentTempStorageLocalization.string("Agent Temp Storage"),
        description: PluginAgentTempStorageLocalization.string(
            "Provides a sandboxed temp file directory for the agent, with automatic cleanup after 7 days."
        ),
        order: 18,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "doc.badge.clock",
    )

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            WriteTempFileTool(),
            ReadTempFileTool(),
            ListTempFilesTool()
        ]
    }

    @MainActor
    public static func pluginAboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(info.displayName)
                    .font(.title2.weight(.semibold))
                Text(info.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
}

enum PluginAgentTempStorageLocalization {
    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module, table: "Localizable")
    }
}
