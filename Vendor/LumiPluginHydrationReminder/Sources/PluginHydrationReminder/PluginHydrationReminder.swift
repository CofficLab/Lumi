import KernelCore
import OSLog
import ProviderDocsView
import ProviderMenuBar
import ProviderStorage
import ProviderSettingView
import SwiftUI

/// Hydration Reminder Plugin: reminds users to stay hydrated.
@MainActor
public final class PluginHydrationReminder: SuperPlugin {
    public static let defaultPluginID = "com.coffic.lumi.plugin.hydration"

    public let id: String
    public let order: Int
    public let metadata: PluginMetadata
    nonisolated let logger: Logger

    public init(
        id: String = PluginHydrationReminder.defaultPluginID,
        order: Int = 10,
        policy: PluginEnablePolicy = .enabledByDefault
    ) {
        self.id = id
        self.order = order
        self.metadata = PluginMetadata(
            id: id,
            name: String(localized: "Hydration", table: "HydrationReminder", bundle: .module, comment: "Name of the hydration reminder plugin"),
            description: String(localized: "Remind you to stay hydrated every 2 hours", table: "HydrationReminder", bundle: .module, comment: "Description of what the Hydration Reminder plugin does"),
            version: "1.0.1",
            category: .general,
            stage: .stable,
            policy: policy
        )
        self.logger = Logger(subsystem: id, category: "HydrationReminder")
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 说明书条目：设置页「通用 → 说明书」中展示
        kernel.resolveProvider((any DocsViewProviding).self)?
            .addManual(DocsEntry(id: id, name: metadata.name) {
                HydrationManualView()
            })

        // 按 CofficLab 存储规范，插件状态落盘在宿主分配的插件专属目录
        // （Binary Plist），而不是 UserDefaults。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            HydrationReminderManager.shared.attachStateStore(directory: storage.pluginDataDirectory(for: id))
        }

        try contributeMenuBar(to: kernel)

        // 设置页标签
        kernel.resolveProvider((any SettingViewProviding).self)?
            .addEntries([
                SettingEntryItem(
                    id: id,
                    title: String(localized: "Hydration", table: "HydrationReminder", bundle: .module, comment: "Name of the hydration reminder plugin"),
                    systemImage: "drop.fill",
                    detail: { HydrationSettingsView() }
                )
            ])
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        try contributeMenuBar(to: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])

        // 清理：卸载插件时停止提醒定时器
        HydrationReminderManager.shared.stop()
    }

    private func contributeMenuBar(to kernel: KernelCoreContainer) throws {
        guard let menuBar = kernel.resolveProvider(MenuBarProviding.self) else { return }
        let ownerID = id
        try kernel.trackContribution {
            menuBar.removeItems(ownedBy: ownerID)
        }
        menuBar.addPopup(MenuBarContribution(
            id: "\(id).popup",
            title: metadata.name,
            order: order,
            ownerPluginID: id
        ) {
            HydrationReminderPopupView()
        })
    }
}
