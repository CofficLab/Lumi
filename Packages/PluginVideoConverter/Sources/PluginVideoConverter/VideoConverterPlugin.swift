import KernelCore
import ProviderContentView
import ProviderDocsView
import SwiftUI

/// 视频转换插件
///
/// 完美复刻自 Lumi 旧版 `VideoConverterPlugin`（KernelLumi → KernelCore 适配）：
/// - 注册视频转换视图为主内容（ContentView，沿用旧版 viewContainers）；
/// - 贡献「关于」与「说明书」文档（沿用旧版 pluginAboutView / pluginManualView）。
///
/// 通过 `SuperPlugin.onBoot(kernel:)` 解析内核中的各 Provider，
/// 用追加语义注册，不覆盖其他插件的贡献。
@MainActor
public final class VideoConverterPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.video-converter"
    public let order = 870

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 注册视频转换视图为主内容（ContentView，沿用旧版 viewContainers）
        if let contentView = kernel.resolveProvider((any ContentViewProviding).self) {
            contentView.setContentView(AnyView(VideoConverterMainView()))
        }

        // 2. 贡献「关于」与「说明书」文档（沿用旧版 pluginAboutView / pluginManualView）
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: "视频转换") { VideoConverterAboutView() })
            docs.addManual(DocsEntry(id: id, name: "视频转换") { VideoConverterManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
