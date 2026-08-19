import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import SwiftUI

/// 白噪音播放插件。
///
/// 完美复刻自 Lumi 旧版 `WhiteNoisePlugin`（KernelLumi → KernelCore 适配）：
/// - 注册白噪音播放视图为主内容（ContentView，沿用旧版 viewContainers）；
/// - 贡献「关于」与「说明书」文档（沿用旧版 pluginAboutView / pluginManualView）。
///
/// 通过 `SuperPlugin.onBoot(kernel:)` 解析内核中的各 Provider，
/// 用追加语义注册，不覆盖其他插件的贡献。
@MainActor
public final class WhiteNoisePlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.white-noise"
    public let order = 261
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.white-noise",
        name: "白噪音",
        description: "白噪音播放插件，提供白噪音主内容视图与说明书文档。",
        category: .general,
        stage: .stable,
        policy: .enabledByDefault
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)

        // 1. 注册 ActivityBar 入口；激活后由插件切换自己的主内容。
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: "白噪音",
                    systemImage: "waveform",
                    order: order,
                    ownerPluginID: id
                ) { activeItemID in
                    guard activeItemID == entryID else { return }
                    contentView?.setContentView(AnyView(WhiteNoiseView()))
                    railView?.activateGroup(id: self.id)
                },
            ])
        } else {
            contentView?.setContentView(AnyView(WhiteNoiseView()))
        }

        // 2. 贡献「关于」与「说明书」文档（沿用旧版 pluginAboutView / pluginManualView）
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: "白噪音") { WhiteNoiseAboutView() })
            docs.addManual(DocsEntry(id: id, name: "白噪音") { WhiteNoiseManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        activityBar?.removeItems(ids: ["\(id).entry"])
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
