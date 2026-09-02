import KernelCore
import KitAgentTool
import KitSuperLog
import os
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderNetwork
import ProviderRailView
import ProviderRootView
import ProviderStorage
import ProviderToolbar
import ProviderToolManager
import SwiftUI

/// App Store Connect 管理插件。
///
/// 该插件保留历史版本的账号、版本、本地化、截图、发布和 Xcode Cloud
/// 能力，但使用当前 KernelCore Provider 注册表作为唯一集成边界。
@MainActor
public final class AppStoreConnectPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.app-store-connect",
        category: "AppStoreConnectPlugin"
    )

    public let id = "com.coffic.lumi.plugin.app-store-connect"
    public let order = 65
    public static let railTabID = "app-store-connect.sidebar"

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.app-store-connect",
        name: AppStoreConnectLocalization.string("AppStoreConnect"),
        description: AppStoreConnectLocalization.string("Manage App Store Connect apps, versions, metadata, screenshots, releases and Xcode Cloud."),
        category: .integration,
        stage: .preview,
        policy: .disabledByDefault
    )

    public var name: String {
        AppStoreConnectLocalization.string("AppStoreConnect")
    }

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        guard let docs = kernel.resolveProvider((any DocsViewProviding).self) else {
            Self.logger.error("\(Self.t) DocsViewProviding not found")
            return
        }
        docs.addAbout(DocsEntry(id: id, name: name) { AboutView() })
        docs.addManual(DocsEntry(id: id, name: name) { AppStoreConnectManualView() })
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        AppStoreConnectPluginRuntimeBridge.configure(kernel: kernel, pluginID: id)

        let network = kernel.resolveProvider((any NetworkProviding).self)
        AppStoreConnectToolSupport.configure(network: network)
        if let network {
            VM.shared.configure(network: network)
            Task { await ScreenshotImageCache.shared.configure(network: network) }
        }

        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        } else {
            Self.logger.error("\(Self.t) ToolManagerProviding not found")
        }

        let rail = kernel.resolveProvider((any RailViewProviding).self)
        rail?.addTabs([
            RailTabItem(
                id: Self.railTabID,
                category: .general,
                title: name,
                systemImage: "app.badge.checkmark",
                order: order
            ) {
                AppStoreConnectRailView(viewModel: VM.shared)
            },
        ])

        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let chatContext = ChatContext(
            id: id,
            title: name,
            subtitle: metadata.description,
            systemImage: "app.badge.checkmark"
        )
        let storage = kernel.resolveProvider((any StorageProviding).self)
        let chatWidthStore = storage.map { value in
            FileChatSectionWidthStore(
                fileURL: value.pluginDataDirectory(for: id)
                    .appendingPathComponent("chat-section-width.plist")
            )
        }
        let railWidthStore = storage.map { value in
            FileRailViewWidthStore(
                fileURL: value.pluginDataDirectory(for: id)
                    .appendingPathComponent("rail-view-width.plist")
            )
        }

        let entryID = "\(id).entry"
        let pluginID = id
        kernel.resolveProvider((any ActivityBarProviding).self)?.addItems([
            ActivityBarItem(
                id: entryID,
                title: name,
                systemImage: "app.badge.checkmark",
                order: order,
                ownerPluginID: id
            ) { state in
                if state == .activated {
                    toolbar?.setVisibleCategories([.global, .general])
                    rootView?.setContentHeaderViewHidden(true)
                    rail?.setVisibleTabID(Self.railTabID)
                    rail?.activateWidthProfile(
                        ownerID: pluginID,
                        recommended: RailViewWidth(minWidth: 260, idealWidth: 320, maxWidth: 460),
                        store: railWidthStore
                    )
                    content?.setContentView(AnyView(MainView()))
                    chat?.setVisible(true)
                    chat?.setContextActive(true)
                    chat?.setActiveContext(chatContext)
                    chat?.activateWidthProfile(
                        ownerID: pluginID,
                        recommended: ChatSectionWidth(minWidth: 300, idealWidth: 360, maxWidth: 560),
                        store: chatWidthStore
                    )
                } else {
                    toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                    rootView?.setContentHeaderViewHidden(false)
                    chat?.setActiveContext(nil)
                    chat?.deactivateWidthProfile(ownerID: pluginID)
                    rail?.deactivateWidthProfile(ownerID: pluginID)
                }
            },
        ])
    }

    public func onReady(kernel: KernelCoreContainer) throws {
        // The network can be registered after the plugin boot phase by some hosts.
        if let network = kernel.resolveProvider((any NetworkProviding).self) {
            AppStoreConnectToolSupport.configure(network: network)
            VM.shared.configure(network: network)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolManagerProviding).self).map { manager in
            Self.agentTools.forEach { manager.remove(id: $0.name) }
        }
        kernel.resolveProvider((any RailViewProviding).self)?.removeTabs(ids: [Self.railTabID])

        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            kernel.resolveProvider((any ToolbarProviding).self)?
                .setVisibleCategories(Set(ToolbarItemCategory.allCases))
            kernel.resolveProvider((any RootViewProviding).self)?
                .setContentHeaderViewHidden(false)
            kernel.resolveProvider((any ChatSectionProviding).self)?.setActiveContext(nil)
            kernel.resolveProvider((any ChatSectionProviding).self)?.deactivateWidthProfile(ownerID: id)
            kernel.resolveProvider((any RailViewProviding).self)?.deactivateWidthProfile(ownerID: id)
            kernel.resolveProvider((any RailViewProviding).self)?
                .setVisibleCategories(Set(RailViewCategory.allCases))
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }
        AppStoreConnectToolSupport.configure(network: nil)
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    public static let agentTools: [any SuperAgentTool] = [
        ListAppStoreConnectAppsTool(),
        ListAppStoreConnectVersionsTool(),
        ReadAppStoreConnectVersionTool(),
        CreateAppStoreConnectVersionTool(),
        ReleaseAppStoreConnectVersionTool(),
        ListAppStoreConnectBuildsTool(),
        AssignAppStoreConnectBuildTool(),
        SubmitAppStoreConnectVersionTool(),
        WithdrawAppStoreConnectSubmissionTool(),
        ListAppStoreConnectLocalizationsTool(),
        CreateAppStoreConnectLocalizationTool(),
        ReadAppStoreConnectLocalizationTool(),
        ListAppStoreConnectScreenshotSetsTool(),
        ListAppStoreConnectScreenshotsTool(),
        UploadAppStoreConnectScreenshotTool(),
        DeleteAppStoreConnectScreenshotTool(),
        ListAppStoreConnectCiProductsTool(),
        ListAppStoreConnectCiWorkflowsTool(),
        ReadAppStoreConnectCiWorkflowTool(),
        ListAppStoreConnectCiBuildRunsTool(),
        UpdateAppStoreConnectLocalizationTool(),
        CreateAppStoreConnectScreenshotSetTool(),
        StartAppStoreConnectCiBuildRunTool(),
        SetAppStoreConnectCiWorkflowEnabledTool(),
    ]
}
