import os
import Foundation
import KernelCore
import KitSuperLog
import ProviderLLMManager
import KitLLM
import ProviderSettingView
import SwiftUI

/// LLM 供应商设置插件（KernelCore 生态）。
///
/// 在设置界面把 `LLMManaging` 中注册的全部供应商展示出来，
/// 按 `isLocal` 区分云端和本地供应商入口。
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

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let manager = kernel.resolveProvider((any LLMManaging).self),
              let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve LLMManaging, SettingViewProviding from kernel")
            return
        }
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
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).remote-providers", "\(id).local-providers"])
    }
}
