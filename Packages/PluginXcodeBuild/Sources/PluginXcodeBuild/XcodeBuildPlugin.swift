import Foundation
import KernelCore
import KitSuperLog
import ProviderSkill
import os

/// Xcode Build 示例技能插件。
///
/// 演示「任何插件在 `onBoot` 从内核解析 `SkillProviding` 并注入自己的技能」：
/// 1. `onBoot` 解析 `SkillProviding`（宿主预注册的 `DefaultSkillProvider`）；
/// 2. 构造 `XcodeBuildSkillContributor` 并 `addProvider` 注入；
/// 3. `onShutdown` 幂等撤回，避免插件卸载后残留技能。
///
/// 接入方式（FactoryLumi）：
/// - `Package.swift` 添加本包依赖；
/// - `PluginFactory.makePlugins()` 追加 `XcodeBuildPlugin()`。
@MainActor
public final class XcodeBuildPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.xcode-build", category: "XcodeBuild")

    public nonisolated static let pluginID = "com.coffic.lumi.plugin.xcode-build"
    public let id = XcodeBuildPlugin.pluginID

    public let order = 60
    public let metadata = PluginMetadata(
        id: XcodeBuildPlugin.pluginID,
        name: "Xcode Build Skill",
        description: "为 Agent 贡献 Xcode 构建技能",
        category: .general,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 从内核解析 SkillProviding。宿主 DefaultProviderFactory 已预注册；
        // 未装配时（如独立测试环境）降级：打印警告但不阻塞插件启动。
        guard let skillProvider = kernel.resolveProvider((any SkillProviding).self) else {
            Self.logger.warning("\(Self.t)SkillProviding not registered; skip skill contribution")
            return
        }

        // 幂等注入：同一插件 ID 不会重复注册。
        guard !skillProvider.isProviderRegistered(providerID: Self.pluginID) else {
            Self.logger.info("\(Self.t)Skill already registered, skip")
            return
        }

        let contributor = XcodeBuildSkillContributor(providerID: Self.pluginID)
        skillProvider.addProvider(contributor)
        Self.logger.info("\(Self.t)Contributed \(contributor.allSkills.count) skill(s) via SkillProviding")
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let skillProvider = kernel.resolveProvider((any SkillProviding).self) {
            skillProvider.removeProvider(providerID: Self.pluginID)
            Self.logger.info("\(Self.t)Revoked skill contribution")
        }
    }
}