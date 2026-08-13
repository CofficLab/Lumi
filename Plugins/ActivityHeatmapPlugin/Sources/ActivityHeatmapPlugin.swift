import Foundation
import KernelLumi
import LumiUI
import SwiftUI

/// ActivityHeatmapPlugin displays a GitHub-style activity heatmap and token usage chart
/// in the settings sidebar, powered by MessageManaging in KernelLumi.
public final class ActivityHeatmapPlugin: LumiPlugin {
    public let id = "com.coffic.activity-heatmap"
    public var name: String {
        LumiPluginLocalization.string("Activity Heatmap", bundle: .module)
    }
    public let order = 9
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta
    public let category: LumiPluginCategory = .general
    public let pluginDescription = "Display daily message activity and token consumption charts."

    /// Shared cache instance for the plugin
    private var cache: ActivityHeatmapCache?

    /// Settings store for user preferences (period, etc.)
    private var settingsStore: ActivityHeatmapSettingsStore?

    /// Cache directory for the plugin data (exposed for settings view to open in Finder)
    package var cacheDirectory: URL? {
        cache?.databaseDirectoryURL
    }

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        // Initialize cache with storage service from kernel
        let storage = kernel.resolveService(StorageProviding.self)
        let storageDirectory = await storage?.pluginDataDirectory(for: "ActivityHeatmap")
        cache = ActivityHeatmapCache(storageDirectory: storageDirectory, pluginID: id)
        settingsStore = ActivityHeatmapSettingsStore(pluginDirectory: storageDirectory)
    }

    public func onReady(kernel: KernelLumi) async throws {}

    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] {
        let messageService = kernel.resolveService(MessageManaging.self)
        let idleTimeProvider = kernel.idleTime
        let idleTimeDataDirectory = kernel.storage?.pluginDataDirectory(for: "IdleTime")
        return [
            SettingsTabItem(
                id: id,
                title: LumiPluginLocalization.string("Activity Heatmap", bundle: .module),
                systemImage: "chart.bar.xaxis",
                order: order
            ) {
                ActivityHeatmapSettingsView(messageService: messageService, cache: self.cache,
                                            settingsStore: self.settingsStore,
                                            idleTimeProvider: idleTimeProvider,
                                            idleTimeDataDirectory: idleTimeDataDirectory)
            },
        ]
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(ActivityHeatmapAboutView())
    }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
