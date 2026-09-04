import AppKit
import KernelCore
import ProviderDocsView
import ProviderSettingView
import ProviderStorage
import ProviderIdleTime
import SwiftUI
import KitSuperLog
import os

/// 空闲时间插件（KernelCore 版本）。
///
/// 由旧版 `Plugins/IdleTimePlugin`（KernelLumi / LumiPlugin 架构）复刻而来：
/// - onBoot 解析内核注册的 `IdleTimeProviding`（FactoryLumi 已装配完整服务），
///   注册活动事件监听（应用激活 / 编辑器保存），把事件喂给服务做休息窗口推断；
/// - 贡献设置页、关于文档；
/// - onShutdown 全部撤回。
@MainActor
public final class IdleTimePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.idle-time", category: "IdleTime")
    public let id = "com.coffic.lumi.plugin.idle-time"
    public let order = 96
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.idle-time",
        name: "Idle Time",
        description: "",
        category: .system,
        stage: .stable,
        policy: .required
    )

    private var eventObserver: IdleTimeEventObserver?
    private var snapshotObserver: IdleTimeSnapshotObserver?
    private var viewModel: AppIdleTimeVM?
    private var provider: (any IdleTimeProviding)?

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: LumiPluginLocalization.string("Idle Time", bundle: .module)) { IdleTimeAboutView() })
            docs.addManual(DocsEntry(id: id, name: LumiPluginLocalization.string("Idle Time", bundle: .module)) { IdleTimeManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 解析 IdleTimeProviding（FactoryLumi 已装配真实 IdleTimeService）。
        let provider = kernel.resolveProvider((any IdleTimeProviding).self)
        self.provider = provider

        // 2. 注册活动事件监听（替代旧版 IdleTimeRootObserver 的职责）。
        if let provider {
            eventObserver = IdleTimeEventObserver(provider: provider)
            let viewModel = AppIdleTimeVM(provider: provider)
            self.viewModel = viewModel
            snapshotObserver = IdleTimeSnapshotObserver(provider: provider) { [weak viewModel] in
                Task { @MainActor in
                    viewModel?.refresh()
                }
            }
        }

        // 3. 设置页：休息窗口详情 + 打开数据目录。
        if let settings = kernel.resolveProvider((any SettingViewProviding).self),
           let storage = kernel.resolveProvider((any StorageProviding).self),
           let viewModel {
            let dataDirectory = storage.pluginDataDirectory(for: "IdleTime")
            let entry = SettingEntryItem(
                id: "\(id).settings",
                title: LumiPluginLocalization.string("Idle Time", bundle: .module),
                systemImage: "moon.zzz",
                order: order
            ) {
                IdleTimeSettingsView(viewModel: viewModel, dataDirectory: dataDirectory)
            }
            settings.addEntries([entry])
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 撤回事件监听。
        eventObserver?.cancel()
        eventObserver = nil
        snapshotObserver?.cancel()
        snapshotObserver = nil
        viewModel = nil
        provider = nil

        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).settings"])
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

}
