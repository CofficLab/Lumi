import LLMKit
import LumiKernel
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

    public func onBoot(kernel: LumiKernel) async throws {
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

    public func onReady(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [
            MiniMaxResponsesProvider(network: kernel.network),
            MiniMaxOpenAIProvider(network: kernel.network),
            MiniMaxAnthropicProvider(network: kernel.network),
        ]
    }

    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] {
        [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }

    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }

    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        [
            StatusBarItem(
                id: "\(id).token-plan",
                title: LumiPluginLocalization.string("MiniMax Token Plan", bundle: .module),
                systemImage: "chart.bar.fill",
                placement: .trailing,
                statusBarView: {
                    StatusBarVisibilityView(kernel: kernel)
                }
            )
        ]
    }

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
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
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Label(LumiPluginLocalization.string("MiniMax", bundle: .module),
                      systemImage: "sparkle")
                    .font(.headline)
                Text(LumiPluginLocalization.string("LLM provider for chat and agent conversations.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
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
