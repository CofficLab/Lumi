import LLMKit
import KernelLumi
import LumiUI
import SwiftUI

@MainActor
public final class KimiCodePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.kimi-code"
    public var name: String {
        LumiPluginLocalization.string("Kimi Code", bundle: .module)
    }
    public let order = 103
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta
    public var category: LumiPluginCategory { .llmProvider }

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        if let storage = kernel.storage {
            AvailabilityDiskCacheDirectoryResolver.set(
                pluginName: "LLMProviderKimiCodePlugin",
                directory: storage.pluginDataDirectory(for: "LLMProviderKimiCodePlugin")
            )
        }
    }

    public func onReady(kernel: KernelLumi) async throws {}

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] {
        [
            KimiCodeOpenAIProvider(network: kernel.network),
            KimiCodeAnthropicProvider(network: kernel.network),
        ]
    }

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
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Label(LumiPluginLocalization.string("Kimi Code", bundle: .module),
                      systemImage: "sparkles")
                    .font(.headline)
                Text(LumiPluginLocalization.string("LLM provider for chat and agent conversations.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
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
}

// MARK: - API Key 静态入口

public extension KimiCodePlugin {
    nonisolated static let apiKeyStorageKey = "DevAssistant_ApiKey_KimiCode"

    nonisolated static var currentApiKey: String {
        resolvedStore().loadMigratingLegacyUserDefaults(forKey: apiKeyStorageKey) ?? ""
    }

    nonisolated static var hasApiKey: Bool { !currentApiKey.isEmpty }

    nonisolated static func setApiKey(_ apiKey: String) {
        resolvedStore().set(apiKey, forKey: apiKeyStorageKey)
    }

    nonisolated static func removeApiKey() {
        resolvedStore().remove(forKey: apiKeyStorageKey)
    }
}

// MARK: - 测试注入

final class _KimiCodePluginKeyStoreBridge: @unchecked Sendable {
    static let shared = _KimiCodePluginKeyStoreBridge()
    private let lock = NSLock()
    private var override: APIKeyStore?

    func withOverride<T>(_ store: APIKeyStore?, _ body: () throws -> T) rethrows -> T {
        lock.lock()
        let previous = override
        override = store
        defer {
            override = previous
            lock.unlock()
        }
        return try body()
    }

    func resolve() -> APIKeyStore {
        return override ?? APIKeyStore.shared
    }
}

private nonisolated func resolvedStore() -> APIKeyStore {
    _KimiCodePluginKeyStoreBridge.shared.resolve()
}