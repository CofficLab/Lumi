import KernelCore
import ProviderActivityBar
import ProviderToolbar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderRootView
import SwiftUI
import KitSuperLog
import os

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
public final class VideoConverterPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.video-converter", category: "VideoConverter")
    public let id = "com.coffic.lumi.plugin.video-converter"
    public let order = 870
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.video-converter",
        name: "视频转换",
        description: "视频格式转换插件，提供视频转换主内容视图与说明书文档。",
        category: .general,
        stage: .stable,
        policy: .disabledByDefault
    )

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: "视频转换") { VideoConverterAboutView() })
            docs.addManual(DocsEntry(id: id, name: "视频转换") { VideoConverterManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        // 1. 在 ActivityBar 注册「视频转换」入口（沿用旧版 ActivityBar 容器入口）
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: VideoConverterLocalization.string("Video Converter"),
                    systemImage: "video",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        toolbar?.setVisibleCategories([.global, .general])
                        contentView?.setContentView(AnyView(VideoConverterMainView()))
                        chat?.setVisible(false)
                        rootView?.setRailView(nil)
                        rootView?.setContentHeaderViewHidden(true)
                    } else {
                        toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                        chat?.setVisible(true)
                        rootView?.setRailView(railView?.makeRailView())
                        rootView?.setContentHeaderViewHidden(false)
                    }
                },
            ])
        } else {
            contentView?.setContentView(AnyView(VideoConverterMainView()))
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(true)
            let railView = kernel.resolveProvider((any RailViewProviding).self)
            let rootView = kernel.resolveProvider((any RootViewProviding).self)
            rootView?.setRailView(railView?.makeRailView())
            rootView?.setContentHeaderViewHidden(false)
        }
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
