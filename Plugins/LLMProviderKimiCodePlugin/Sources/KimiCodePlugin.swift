import LLMKit
import LumiKernel
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
    public var category: LumiPluginCategory { .llmProvider }

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        if let storage = kernel.storage {
            AvailabilityDiskCacheDirectoryResolver.set(
                pluginName: "LLMProviderKimiCodePlugin",
                directory: storage.pluginDataDirectory(for: "LLMProviderKimiCodePlugin")
            )
        }
    }

    public func onReady(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [
            KimiCodeOpenAIProvider(network: kernel.network),
            KimiCodeAnthropicProvider(network: kernel.network),
        ]
    }

    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
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