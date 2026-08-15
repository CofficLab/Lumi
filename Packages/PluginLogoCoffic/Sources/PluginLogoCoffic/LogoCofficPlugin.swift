import KernelCore
import ProviderLogo
import SwiftUI

/// Coffic Logo 插件
///
/// 完美复刻自 Lumi 旧版 `LogoCofficPlugin`（KernelLumi → KernelCore 适配）：
/// 贡献咖啡主题 Logo（提供动画咖啡杯图标）。
///
/// 精简内核（SuperPlugin）没有 `logoItems` 声明式贡献点，因此本插件在
/// `onBoot(kernel:)` 中主动解析 `LogoProviding`，用追加语义注册自己的
/// `LogoItem`；消费方（如菜单栏图标）按 `order` 优先级取用。
@MainActor
public final class LogoCofficPlugin: SuperPlugin {
    public let id = "com.lumi.plugin.logo-coffic"
    public let order = 100

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let logo = kernel.resolveProvider((any LogoProviding).self) else {
            return
        }

        logo.registerLogoItem(
            LogoItem(
                id: id,
                order: order,
                makeView: { scene in
                    CofficLogoView(scene: scene)
                }
            )
        )
    }
}
