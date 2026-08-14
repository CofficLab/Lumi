import LLMKit
import KernelLumi
import LumiUI
import SwiftUI

@MainActor
public final class MiniMaxPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.minimax"
    public var name: String {
        LumiPluginLocalization.string("MiniMax", bundle: .module)
    }
    public let order = 104
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta
    public var category: LumiPluginCategory { .llmProvider }

    private var videoRecordStore: MiniMaxVideoRecordStore?
    private var imageRecordStore: MiniMaxImageRecordStore?
    private var musicRecordStore: MiniMaxMusicRecordStore?

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        if let storage = kernel.storage {
            AvailabilityDiskCacheDirectoryResolver.set(
                pluginName: "LLMProviderMiniMax",
                directory: storage.pluginDataDirectory(for: "LLMProviderMiniMax")
            )

            let videoDatabaseURL = storage.pluginDataDirectory(for: "LLMProviderMiniMax")
                .appendingPathComponent("video_records", isDirectory: true)
            videoRecordStore = MiniMaxVideoRecordStore(databaseRootURL: videoDatabaseURL)

            let imageDatabaseURL = storage.pluginDataDirectory(for: "LLMProviderMiniMax")
                .appendingPathComponent("image_records", isDirectory: true)
            imageRecordStore = MiniMaxImageRecordStore(databaseRootURL: imageDatabaseURL)

            let musicDatabaseURL = storage.pluginDataDirectory(for: "LLMProviderMiniMax")
                .appendingPathComponent("music_records", isDirectory: true)
            musicRecordStore = MiniMaxMusicRecordStore(databaseRootURL: musicDatabaseURL)
        }
    }

    public func onReady(kernel: KernelLumi) async throws {}

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] {
        [
            MiniMaxResponsesProvider(network: kernel.network),
            MiniMaxOpenAIProvider(network: kernel.network),
            MiniMaxAnthropicProvider(network: kernel.network),
        ]
    }

    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] {
        [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }

    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }

    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }

    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] {
        [
            ChatSectionToolbarItem(
                id: "\(id).token-plan",
                placement: .trailing
            ) {
                StatusBarVisibilityView(kernel: kernel)
            },
        ]
    }

    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] {
        guard let store = videoRecordStore else { return [] }
        return [
            SettingsTabItem(
                id: "\(id).video-records",
                title: "Video History",
                systemImage: "video.circle",
                order: order
            ) {
                VideoRecordsSettingsView(store: store)
            },
        ]
    }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(
            LLMProviderLandingPage(displayName: LumiPluginLocalization.string("MiniMax", bundle: .module), icon: "sparkle")
        )
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
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        let apiKeyProvider: @Sendable () -> String? = {
            APIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: "DevAssistant_ApiKey_MiniMax")
        }

        var tools: [any LumiAgentTool]

        if let network = kernel.network {
            let api = MiniMaxVideoAPI(network: network, apiKeyProvider: apiKeyProvider)
            tools = [MiniMaxVideoTool(client: api, recordStore: videoRecordStore)]
        } else {
            let api = MiniMaxVideoAPI(apiKeyProvider: apiKeyProvider)
            tools = [MiniMaxVideoTool(client: api, recordStore: videoRecordStore)]
        }

        if let store = videoRecordStore {
            tools.append(MiniMaxListVideosTool(store: store))
            tools.append(MiniMaxGetVideoTool(store: store))
        }

        if let network = kernel.network {
            let imageAPI = MiniMaxImageAPI(network: network, apiKeyProvider: apiKeyProvider)
            tools.append(MiniMaxImageTool(client: imageAPI, recordStore: imageRecordStore))
        } else {
            let imageAPI = MiniMaxImageAPI(apiKeyProvider: apiKeyProvider)
            tools.append(MiniMaxImageTool(client: imageAPI, recordStore: imageRecordStore))
        }

        if let store = imageRecordStore {
            tools.append(MiniMaxListImagesTool(store: store))
            tools.append(MiniMaxGetImageTool(store: store))
        }

        if let network = kernel.network {
            let musicAPI = MiniMaxMusicAPI(network: network, apiKeyProvider: apiKeyProvider)
            tools.append(MiniMaxMusicTool(client: musicAPI, recordStore: musicRecordStore))
        } else {
            let musicAPI = MiniMaxMusicAPI(apiKeyProvider: apiKeyProvider)
            tools.append(MiniMaxMusicTool(client: musicAPI, recordStore: musicRecordStore))
        }

        if let store = musicRecordStore {
            tools.append(MiniMaxListMusicTool(store: store))
            tools.append(MiniMaxGetMusicTool(store: store))
        }

        return tools
    }
}
