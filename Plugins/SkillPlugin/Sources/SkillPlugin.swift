import LumiChatKit
import LumiCoreKit
import SwiftUI
import os

/// Skill 插件
///
/// 负责扫描 `.agent/skills/` 目录，加载领域技能并注入到 LLM 上下文。
public enum SkillPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "sparkles"
    
    // MARK: - 日志
    
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.skill")
    nonisolated static let verbose = false

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.skill",
        displayName: LumiPluginLocalization.string("Skills", bundle: .module),
        description: LumiPluginLocalization.string("Load domain skills from .agent/skills/ directory", bundle: .module),
        order: 51
    )

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        [SkillChatMiddleware()]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.isChatSectionVisible else {
            return []
        }

        let projectPath = context.resolve(LumiCurrentProjectPathProviding.self)?.currentProjectPath ?? ""
        return [
            LumiStatusBarItem(
                id: "\(info.id).skills",
                title: LumiPluginLocalization.string("Skills", bundle: .module),
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    SkillStatusBarView(projectPath: projectPath)
                }
            )
        ]
    }
}
