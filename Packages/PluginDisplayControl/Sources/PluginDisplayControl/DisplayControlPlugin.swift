import Foundation
import KernelCore
import ProviderActivityBar
import ProviderToolbar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderRootView
import ProviderStorage
import SwiftUI
import LumiLoggingKit
import os

@MainActor
public final class DisplayControlPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.display-control", category: "DisplayControl")
    public let id = "com.coffic.lumi.plugin.display-control"
    public let order = 210
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.display-control",
        name: pluginLocalization.string("Display Control"),
        description: pluginLocalization.string("Control brightness, volume, and contrast for external displays via DDC/CI."),
        category: .system,
        stage: .preview,
        policy: .disabledByDefault
    )

    /// 历史实现把各显示器的记忆值存在 `UserDefaults.standard`，
    /// 键名形如 `displayControl.value.<displayStorageID>.<kind>`。
    /// 目录名未变过，无需版本根搬迁。
    public let legacyDataDirectoryNames: [String] = []

    private var viewModel: DisplayControlViewModel?
    private var observer: DisplayControlObserver?

    public init() {}

    /// 把 `UserDefaults.standard` 中的旧显示器记忆值导入插件专属存储。
    ///
    /// 仅导入插件存储中尚不存在的键，避免覆盖插件内的后续修改。
    /// `UserDefaults` 原 key 保留，便于回退。
    public func migrateData(context: PluginDataMigrationContext) throws {
        let prefix = "displayControl.value."
        guard let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") else {
            return
        }
        let legacyEntries = domain.filter { $0.key.hasPrefix(prefix) }
        guard !legacyEntries.isEmpty else { return }

        let store = DisplayControlPluginLocalStore(settingsDirectory: context.currentPluginDataDirectory)
        var imported = 0
        for (key, value) in legacyEntries {
            guard let doubleValue = value as? Double, !store.contains(key) else { continue }
            store.set(doubleValue, forKey: key)
            imported += 1
        }
        if imported > 0 {
            Self.logger.info("\(Self.t)Imported \(imported) display value entries from UserDefaults")
        }
    }

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { DisplayControlAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { DisplayControlManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 存储目录注入必须早于 DisplayControlPluginLocalStore.shared 的首次访问。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            DisplayControlRuntime.configure(settingsDirectory: storage.pluginDataDirectory(for: id))
        }
        let viewModel = DisplayControlViewModel()
        self.viewModel = viewModel
        observer?.cancel()
        observer = DisplayControlObserver(viewModel: viewModel)
        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let entryID = "\(id).entry"
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: metadata.name,
                    systemImage: "display",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        toolbar?.setVisibleCategories([.global, .system])
                        content?.setContentView(AnyView(DisplayControlView(viewModel: viewModel)))
                        chat?.setVisible(false)
                        rootView?.setRailView(nil)
                        rootView?.setContentHeaderViewHidden(true)
                    } else {
                        toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                        chat?.setVisible(true)
                        rootView?.setRailView(railView?.makeRailView())
                        rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
                        rootView?.setContentHeaderViewHidden(false)
                    }
                },
            ])
        } else {
            content?.setContentView(AnyView(DisplayControlView(viewModel: viewModel)))
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        observer?.cancel()
        observer = nil
        viewModel = nil
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            let railView = kernel.resolveProvider((any RailViewProviding).self)
            kernel.resolveProvider((any RootViewProviding).self)?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
        }
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
