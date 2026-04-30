import SwiftUI
import MagicKit
import os

/// Skill 插件
///
/// 通过 `.agent/skills/` 目录提供轻量级的领域知识扩展机制。
/// 自动扫描 Skill 文件，将摘要注入 LLM Prompt，并在状态栏显示可用 Skill 数量。
actor SkillPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.skill")

    nonisolated static let emoji = "✨"
    nonisolated static let verbose: Bool = false

    // MARK: - 插件基本信息

    static let id = "Skill"
    static let displayName = String(localized: "Skills", table: "Skill")
    static let description = String(localized: "Load domain skills from .agent/skills/ directory", table: "Skill")
    static let iconName = "sparkles"
    static var order: Int { 51 }
    static let enable: Bool = true
    static let isConfigurable: Bool = false

    static let shared = SkillPlugin()

    // MARK: - 插件生命周期

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✨ SkillPlugin 注册")
        }
    }

    nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✨ SkillPlugin 启用")
        }
    }

    nonisolated func onDisable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✨ SkillPlugin 禁用")
        }
    }

    // MARK: - 发送中间件

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(SkillSendMiddleware())]
    }

    // MARK: - 状态栏

    @MainActor
    func addStatusBarTrailingView() -> AnyView? {
        AnyView(SkillStatusBarView())
    }
}
