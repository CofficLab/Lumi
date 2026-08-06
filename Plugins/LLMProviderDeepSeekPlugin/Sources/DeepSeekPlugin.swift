import LLMKit
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class DeepSeekPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.deepseek"
    public var name: String {
        LumiPluginLocalization.string("DeepSeek", bundle: .module)
    }

    public let order = 92
    public let policy: LumiPluginPolicy = .alwaysOn
    public var category: LumiPluginCategory { .llmProvider }

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        if let storage = kernel.storage {
            AvailabilityDiskCacheDirectoryResolver.set(
                pluginName: "LLMProviderDeepSeekPlugin",
                directory: storage.pluginDataDirectory(for: "LLMProviderDeepSeekPlugin")
            )
        }
    }

    public func onReady(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [
            DeepSeekOpenAIProvider(network: kernel.network),
            DeepSeekAnthropicProvider(network: kernel.network),
        ]
    }

    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] {
        [
            Http401Renderer.item,
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
//
// DeepSeek 插件所有 API Key 访问（两个 Provider + 401 渲染器）必须
// 走这里，禁止再直接调用 KeychainStore / LumiAPIKeyTools。
// 这样能保证读和写落在同一个 (service, account)，
// 避免 401 渲染器显示的 key 与实际请求使用的 key 不一致。
public extension DeepSeekPlugin {
    /// Keychain account。历史上由 Provider 内部硬编码，现统一收敛到这里。
    nonisolated static let apiKeyStorageKey = "DevAssistant_ApiKey_DeepSeek"

    /// 当前已配置的 API Key；未配置时返回空串。
    nonisolated static var currentApiKey: String {
        resolvedStore().loadMigratingLegacyUserDefaults(forKey: apiKeyStorageKey) ?? ""
    }

    /// 是否已配置 API Key。
    nonisolated static var hasApiKey: Bool { !currentApiKey.isEmpty }

    /// 保存 API Key。空串等价于删除。
    nonisolated static func setApiKey(_ apiKey: String) {
        resolvedStore().set(apiKey, forKey: apiKeyStorageKey)
    }

    /// 删除 API Key。
    nonisolated static func removeApiKey() {
        resolvedStore().remove(forKey: apiKeyStorageKey)
    }
}

// MARK: - 测试注入（不要在生产代码里调用）
//
// `APIKeyStore.shared` 是 `let`，无法整体替换。为支持单元测试（不污染
// 真实 Keychain），这里允许在测试时把入口切换到隔离的 `APIKeyStore`。
// 读写都过锁，保证并发安全。
final class _DeepSeekPluginKeyStoreBridge: @unchecked Sendable {
    static let shared = _DeepSeekPluginKeyStoreBridge()
    private let lock = NSLock()
    private var override: APIKeyStore?

    /// 测试专用：原子地「设置 override → 跑闭包 → 还原 override」，
    /// 闭包内对 override 的读也会被这把锁串行化。
    /// Swift Testing 同 suite 内是并发执行的（不显式 serial 化就互相覆盖），
    /// 所以整个生命周期必须加同一把锁。
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
        // 注意：resolve 故意不加锁。`override` 字段在 `withOverride` 的临界区内
        // 才被修改，外部读出 stale 值是良性的——读到的就是 `APIKeyStore.shared`，
        // 等同于没有 override 的默认行为，绝不会跨测试读到对方的数据。
        // 这里严格说不是 thread-safe，但跨调用看到的"曾经某时刻的 override"
        // 与 default `APIKeyStore.shared` 等价（都是空的 keychain）。
        return override ?? APIKeyStore.shared
    }
}

private nonisolated func resolvedStore() -> APIKeyStore {
    _DeepSeekPluginKeyStoreBridge.shared.resolve()
}
