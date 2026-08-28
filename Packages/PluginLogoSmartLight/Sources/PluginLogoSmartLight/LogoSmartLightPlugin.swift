import KernelCore
import os
import ProviderLogo
import KitSuperLog
import SwiftUI

/// Smart Light Logo 插件
///
/// 完美复刻自 Lumi 旧版 `LogoSmartLightPlugin`（KernelLumi → KernelCore 适配）：
/// 贡献智能灯光主题 Logo（提供动画灯泡图标）。
///
/// 精简内核（SuperPlugin）没有 `logoItems` 声明式贡献点，因此本插件在
/// `onBoot(kernel:)` 中主动解析 `LogoProviding`，用追加语义注册自己的
/// `LogoItem`；消费方（如菜单栏图标）按 `order` 优先级取用。
@MainActor
public final class LogoSmartLightPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.logo-smart-light")
    nonisolated public static let emoji = "💡"
    nonisolated static let verbose = false

    public let id = "com.lumi.plugin.logo-smart-light"
    public let order = 200
    public let metadata = PluginMetadata(
        id: "com.lumi.plugin.logo-smart-light",
        name: "智能灯光 Logo",
        description: "贡献智能灯光主题 Logo，提供动画灯泡图标。",
        category: .design,
        stage: .stable,
        policy: .required
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let logo = kernel.resolveProvider((any LogoProviding).self) else {
            Self.logger.info("\(Self.t)未装配 LogoProviding，跳过 Smart Light Logo 注册")
            return
        }

        logo.registerLogoItem(
            LogoItem(
                id: id,
                order: order,
                makeView: { scene in
                    SmartLightLogoView(scene: scene)
                }
            )
        )
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Smart Light Logo 项: \(self.id)")
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any LogoProviding).self)?.unregisterLogoItem(id: id)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注销 Smart Light Logo 项: \(self.id)")
        }
    }
}
