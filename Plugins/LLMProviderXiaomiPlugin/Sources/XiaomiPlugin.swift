import LLMKit
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class XiaomiPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.xiaomi"
    public var name: String {
        LumiPluginLocalization.string("Xiaomi", bundle: .module)
    }
    public let order = 102
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta
    public var category: LumiPluginCategory { .llmProvider }

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        if let storage = kernel.storage {
            AvailabilityDiskCacheDirectoryResolver.set(
                pluginName: "LLMProviderXiaomiPlugin",
                directory: storage.pluginDataDirectory(for: "LLMProviderXiaomiPlugin")
            )
        }
    }

    public func onReady(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [
            XiaomiProvider(network: kernel.network),
            XiaomiAPIProvider(network: kernel.network),
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
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Label(LumiPluginLocalization.string("Xiaomi", bundle: .module),
                      systemImage: "circle")
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
}

// MARK: - API Key 静态入口
//
// Xiaomi 插件所有 API Key 访问（两个 Provider + 渲染器）必须
// 走这里，禁止再直接调用 KeychainStore / LumiAPIKeyTools。
// Xiaomi 有两个 Provider，各自使用独立的 storage key。
public extension XiaomiPlugin {
    /// XiaomiProvider (TokenPlan) 的 Keychain account。
    nonisolated static let apiKeyStorageKey = "DevAssistant_ApiKey_Xiaomi"

    /// XiaomiAPIProvider 的 Keychain account。
    nonisolated static let apiKeyStorageKeyForAPI = "DevAssistant_ApiKey_XiaomiAPI"

    /// 当前已配置的 API Key（TokenPlan）；未配置时返回空串。
    nonisolated static var currentApiKey: String {
        resolvedStore().loadMigratingLegacyUserDefaults(forKey: apiKeyStorageKey) ?? ""
    }

    /// 当前已配置的 API Key（API）；未配置时返回空串。
    nonisolated static var currentApiKeyForAPI: String {
        resolvedStore().loadMigratingLegacyUserDefaults(forKey: apiKeyStorageKeyForAPI) ?? ""
    }

    /// 是否已配置 API Key（任意一种）。
    nonisolated static var hasApiKey: Bool {
        !currentApiKey.isEmpty || !currentApiKeyForAPI.isEmpty
    }

    /// 保存 API Key（TokenPlan）。空串等价于删除。
    nonisolated static func setApiKey(_ apiKey: String) {
        resolvedStore().set(apiKey, forKey: apiKeyStorageKey)
    }

    /// 保存 API Key（API）。空串等价于删除。
    nonisolated static func setApiKeyForAPI(_ apiKey: String) {
        resolvedStore().set(apiKey, forKey: apiKeyStorageKeyForAPI)
    }

    /// 删除 API Key（TokenPlan）。
    nonisolated static func removeApiKey() {
        resolvedStore().remove(forKey: apiKeyStorageKey)
    }

    /// 删除 API Key（API）。
    nonisolated static func removeApiKeyForAPI() {
        resolvedStore().remove(forKey: apiKeyStorageKeyForAPI)
    }
}

// MARK: - 测试注入（不要在生产代码里调用）
//
// `APIKeyStore.shared` 是 `let`，无法整体替换。为支持单元测试（不污染
// 真实 Keychain），这里允许在测试时把入口切换到隔离的 `APIKeyStore`。
// 读写都过锁，保证并发安全。
final class _XiaomiPluginKeyStoreBridge: @unchecked Sendable {
    static let shared = _XiaomiPluginKeyStoreBridge()
    private let lock = NSLock()
    private var override: APIKeyStore?

    /// 测试专用：原子地「设置 override → 跑闭包 → 还原 override」。
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
    _XiaomiPluginKeyStoreBridge.shared.resolve()
}
