import SwiftUI
import LumiUI
import SuperLogKit
import SkillKit
import LumiCoreKit
import os

/// Skill 插件
///
/// 通过 `.agent/skills/` 目录提供轻量级的领域知识扩展机制。
/// 自动扫描 Skill 文件，将摘要注入 LLM Prompt，并在状态栏显示可用 Skill 数量。
public actor SkillPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.skill")

    public nonisolated static let emoji = "✨"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    // MARK: - 插件基本信息

    public static let id = "Skill"
    public static let displayName = String(localized: "Skills", bundle: .module)
    public static let description = String(localized: "Load domain skills from .agent/skills/ directory", bundle: .module)
    public static let iconName = "sparkles"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 51 }

    public static let shared = SkillPlugin()

    // MARK: - 插件生命周期

    public nonisolated func onRegister() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)✨ SkillPlugin 注册")
            }
        }
    }

    public nonisolated func onEnable() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)✨ SkillPlugin 启用")
            }
        }
    }

    public nonisolated func onDisable() {
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(Self.t)✨ SkillPlugin 禁用")
            }
        }
    }

    // MARK: - 发送中间件

    @MainActor
    public func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "Skills 扩展知识",
                subtitle: "从 .agent/skills 加载领域技能，并把摘要注入给助手。",
                icon: Self.iconName,
                accent: .purple,
                metrics: [
                    PluginPosterSupport.metric("SKILL.md", "技能"),
                    PluginPosterSupport.metric("Prompt", "注入"),
                ],
                rows: ["扫描技能目录", "状态栏数量", "上下文注入"],
                chips: ["Agent", "Skills", "上下文"]
            ),
        ]
    }

    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(SkillSendMiddleware())]
    }

    // MARK: - 状态栏

    @MainActor
    public func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        AnyView(SkillStatusBarView(projectPath: context.currentProjectPath))
    }
}
