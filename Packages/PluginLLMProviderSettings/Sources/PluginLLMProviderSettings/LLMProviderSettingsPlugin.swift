import Foundation
import KernelCore
import ProviderLLMManager
import KitLLM
import ProviderSettingView
import SwiftUI

/// LLM 供应商设置插件（KernelCore 生态）。
///
/// 在设置界面把 `LLMProviderManagerProviding` 中注册的全部供应商展示出来，
/// 复刻旧版 `LLMProviderManagerPlugin` 的 Cloud / Local 两个设置入口：
/// - 「云端供应商」：远程（非本地）供应商列表 + API Key 管理 + 模型选择；
/// - 「本地供应商」：本地（`isLocal`）供应商列表 + 模型选择（无需 API Key）。
///
/// 页面数据来自管理器（`allProviders()` / `selectedProviderID` /
/// `selectedModel` / `select(providerID:model:)`），并通过 ObservableObject
/// 订阅管理器变化即时刷新。
@MainActor
public final class LLMProviderSettingsPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider-settings"
    public let order = 100

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let manager = kernel.resolveProvider((any LLMManaging).self),
              let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            return
        }
        settings.addEntries([
            SettingEntryItem(
                id: "\(id).remote-providers",
                title: "云端供应商",
                systemImage: "cloud",
                order: 100
            ) {
                ProviderSettingsPage(manager: manager, isLocal: false)
            },
            SettingEntryItem(
                id: "\(id).local-providers",
                title: "本地供应商",
                systemImage: "cpu",
                order: 101
            ) {
                ProviderSettingsPage(manager: manager, isLocal: true)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).remote-providers", "\(id).local-providers"])
    }
}
