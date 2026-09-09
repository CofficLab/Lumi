import os
import Foundation
import KernelCore
import KitSuperLog
import ProviderLLMManager
import ProviderStorage
import KitLLM
import ProviderSettingView
import SwiftUI

/// LLM 供应商设置插件（KernelCore 生态）。
///
/// 在设置界面把 `LLMManaging` 中注册的全部供应商展示出来，
/// 按 `isLocal` 区分云端和本地供应商入口。
///
/// 同时创建并注册 `UserDefinedCloudProviderStore`，供 onboarding 页面
/// 和设置界面共享自定义供应商数据。
@MainActor
public final class LLMProviderSettingsPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.llm-provider-settings", category: "LLMProviderSettings")

    public let id = "com.coffic.lumi.plugin.llm-provider-settings"
    public let order = 100
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.llm-provider-settings",
        name: "LLMProviderSettings 供应商",
        description: "",
        category: .llm,
        stage: .stable,
        policy: .alwaysOn
    )

    private var downloadViewModels: [String: ProviderModelDownloadViewModel] = [:]
    private var downloadObservers: [String: ProviderModelDownloadObserver] = [:]
    private var userProviderStore: UserDefinedCloudProviderStore?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let manager = kernel.resolveProvider((any LLMManaging).self),
              let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve LLMManaging, SettingViewProviding from kernel")
            return
        }
        let storage = kernel.resolveProvider((any StorageProviding).self)
        let configURL = storage?
            .pluginDataDirectory(for: id)
            .appendingPathComponent("user-cloud-providers.json", isDirectory: false)
        let store = UserDefinedCloudProviderStore(fileURL: configURL)
        store.attach(
            manager: manager,
            apiService: VendorAPIService(
                networkProvider: kernel.resolveProvider((any LLMNetworkProviding).self)
            )
        )
        userProviderStore = store

        // 注册 Store 为 Provider，供其他插件（如 PluginLLMManager 的 onboarding 页面）使用。
        try kernel.registerProvider(
            (any UserDefinedCloudProviderStoreProviding).self,
            DefaultUserDefinedCloudProviderStoreProviding(store: store)
        )

        downloadObservers.values.forEach { $0.cancel() }
        downloadObservers.removeAll()
        downloadViewModels.removeAll()
        for provider in manager.allProviders() {
            guard let downloader = provider as? any LLMModelDownloadProviding else { continue }
            let viewModel = ProviderModelDownloadViewModel(initialState: downloader.downloadState)
            downloadViewModels[provider.providerInfo.id] = viewModel
            downloadObservers[provider.providerInfo.id] = ProviderModelDownloadObserver(
                downloader: downloader,
                viewModel: viewModel
            )
        }
        settings.addEntries([
            SettingEntryItem(
                id: "\(id).remote-providers",
                title: "云端供应商",
                systemImage: "cloud",
                order: 100
            ) {
                CloudProviderSettingsPage(
                    manager: manager,
                    customProviderStore: store,
                    downloadViewModel: { [weak self] providerID in
                        self?.downloadViewModels[providerID]
                    }
                )
            },
            SettingEntryItem(
                id: "\(id).local-providers",
                title: "本地供应商",
                systemImage: "cpu",
                order: 101
            ) {
                LocalProviderSettingsPage(
                    manager: manager,
                    customProviderStore: store,
                    downloadViewModel: { [weak self] providerID in
                        self?.downloadViewModels[providerID]
                    }
                )
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        downloadObservers.values.forEach { $0.cancel() }
        downloadObservers.removeAll()
        downloadViewModels.removeAll()
        if let manager = kernel.resolveProvider((any LLMManaging).self) {
            userProviderStore?.configurations.forEach { manager.unregister(id: $0.id) }
        }
        userProviderStore = nil
        // 内核会按插件归属自动撤回 onBoot 注册的 UserDefinedCloudProviderStoreProviding。
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).remote-providers", "\(id).local-providers"])
    }
}

/// `UserDefinedCloudProviderStoreProviding` 的默认实现。
@MainActor
final class DefaultUserDefinedCloudProviderStoreProviding: UserDefinedCloudProviderStoreProviding {
    let store: UserDefinedCloudProviderStore

    init(store: UserDefinedCloudProviderStore) {
        self.store = store
    }
}
