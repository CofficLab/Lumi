import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import SwiftUI

/// 视频转换插件
///
/// 完美复刻自 Lumi 旧版 `VideoConverterPlugin`（KernelLumi → KernelCore 适配）：
/// - 在 ActivityBar 注册「视频转换」入口（沿用旧版 ActivityBar 容器入口）；
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
        // 1. 在 ActivityBar 注册「视频转换」入口（沿用旧版 ActivityBar 容器入口）
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            activityBar.addItems([
                ActivityBarItem(
                    id: "\(id).entry",
                    title: VideoConverterLocalization.string("Video Converter"),
                    systemImage: "video",
                    order: order
                ),
            ])
        }

        // 2. 注册视频转换视图为主内容
        if let contentView = kernel.resolveProvider((any ContentViewProviding).self) {
            contentView.setContentView(AnyView(VideoConverterMainView()))
        }

        // 3. 贡献「关于」与「说明书」文档
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: "视频转换") { VideoConverterAboutView() })
            docs.addManual(DocsEntry(id: id, name: "视频转换") { VideoConverterManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ActivityBarProviding).self)?.removeItems(ids: ["\(id).entry"])
        kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
