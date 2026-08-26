import AppKit
import KernelCore
import ProviderDocsView
import ProviderMenuBar
import ProviderSettingView
import ProviderStorage
import ProviderIdleTime
import SwiftUI

/// 空闲时间插件（KernelCore 版本）。
///
/// 由旧版 `Plugins/IdleTimePlugin`（KernelLumi / LumiPlugin 架构）复刻而来：
/// - onBoot 解析内核注册的 `IdleTimeProviding`（FactoryLumi 已装配完整服务），
///   注册活动事件监听（应用激活 / 编辑器保存），把事件喂给服务做休息窗口推断；
/// - 贡献菜单栏弹窗（休息窗口快照与 24 小时活动热条）、设置页、关于文档；
/// - onShutdown 全部撤回。
@MainActor
public final class IdleTimePlugin: SuperPlugin {
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

    /// 事件观察者 token（onShutdown 时移除）。
    private var observers: [NSObjectProtocol] = []
    private var provider: (any IdleTimeProviding)?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 1. 解析 IdleTimeProviding（FactoryLumi 已装配真实 IdleTimeService）。
        let provider = kernel.resolveProvider((any IdleTimeProviding).self)
        self.provider = provider

        // 2. 注册活动事件监听（替代旧版 IdleTimeRootObserver 的职责）。
        if let provider {
            registerEventObservers(provider: provider)
        }

        // 3. 菜单栏弹窗：休息窗口快照 + 24 小时活动热条。
        if let menuBar = kernel.resolveProvider((any MenuBarProviding).self) {
            menuBar.addPopup(MenuBarPopupItem(id: "\(id).popover", title: LumiPluginLocalization.string("Idle Time", bundle: .module), order: order) {
                IdleTimeStatusBarPopover(provider: provider)
            })
        }

        // 4. 设置页：休息窗口详情 + 打开数据目录。
        if let settings = kernel.resolveProvider((any SettingViewProviding).self),
           let storage = kernel.resolveProvider((any StorageProviding).self) {
            let dataDirectory = storage.pluginDataDirectory(for: "IdleTime")
            let entry = SettingEntryItem(
                id: "\(id).settings",
                title: LumiPluginLocalization.string("Idle Time", bundle: .module),
                systemImage: "moon.zzz",
                order: order
            ) {
                IdleTimeSettingsView(provider: provider, dataDirectory: dataDirectory)
            }
            settings.addEntries([entry])
        }

        // 5. 关于文档。
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: LumiPluginLocalization.string("Idle Time", bundle: .module)) { IdleTimeAboutView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 撤回事件监听。
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        provider = nil

        kernel.resolveProvider((any MenuBarProviding).self)?
            .removeItems(ids: ["\(id).popover"])
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).settings"])
        kernel.resolveProvider((any DocsViewProviding).self)?
            .removeEntries(id: id)
    }

    // MARK: - 事件监听（替代旧版 IdleTimeRootObserver）

    private func registerEventObservers(provider: any IdleTimeProviding) {
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { await provider.record(.appBecameActive) }
        })

        observers.append(center.addObserver(
            forName: .lumiEditorSave,
            object: nil,
            queue: .main
        ) { _ in
            Task { await provider.record(.fileSave) }
        })
    }
}
