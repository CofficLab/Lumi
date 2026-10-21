import KernelCore
import KitTestIsolation
import ProviderActivityBar
import ProviderToolbar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderStorage
import ProviderRailView
import ProviderRootView
import SwiftUI
import LumiLoggingKit
import os

enum InputPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?
    nonisolated(unsafe) static var pluginDirectory: URL?

    /// 生产环境兜底数据根目录。
    static var productionFallbackRootDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
    }

    /// 生产环境兜底插件目录。
    static var productionFallbackPluginDirectory: URL {
        #if DEBUG
        let versionedRoot = "db_debug_v6"
        #else
        let versionedRoot = "db_production_v6"
        #endif
        return productionFallbackRootDirectory
            .appendingPathComponent("com.coffic.Lumi", isDirectory: true)
            .appendingPathComponent(versionedRoot, isDirectory: true)
            .appendingPathComponent("com.coffic.lumi.plugin.input-manager", isDirectory: true)
    }

    /// 插件数据目录。
    ///
    /// 测试进程下未注入即失败，杜绝静默写入本机真实数据目录。
    static var resolvedPluginDirectory: URL {
        IsolatedDirectoryGuard.directory(
            injected: pluginDirectory,
            owner: "InputPluginRuntimeBridge",
            accessor: "resolvedPluginDirectory",
            fallback: { productionFallbackPluginDirectory }
        )
    }
}

@MainActor
public final class InputPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.input-manager", category: "Input")
    public let id = "com.coffic.lumi.plugin.input-manager"
    public let legacyDataDirectoryNames = ["InputPlugin"]
    public let order = 70
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.input-manager",
        name: pluginLocalization.string("Input Manager"),
        description: pluginLocalization.string("Configure input methods and their behavior."),
        category: .system,
        stage: .preview,
        policy: .disabledByDefault
    )

    private let activityItemID = "com.coffic.lumi.plugin.input-manager.entry"
    private var eventObserver: InputEventObserver?
    private var settingsObserver: InputSettingsObserver?
    private var viewModel: InputSettingsViewModel?

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { InputAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { InputManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 存储目录注入必须早于 InputService.shared 的首次访问：
        // InputService 初始化时会构造 InputPluginLocalStore，进而读取插件数据目录。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            InputPluginRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
            InputPluginRuntimeBridge.pluginDirectory = storage.pluginDataDirectory(for: id)
        }

        let inputService = InputService.shared
        let viewModel = InputSettingsViewModel()
        self.viewModel = viewModel
        settingsObserver = InputSettingsObserver(viewModel: viewModel, service: inputService)
        eventObserver?.cancel()
        eventObserver = InputEventObserver(
            onApplicationActivation: { [weak inputService] app in
                inputService?.handleAppActivation(app)
            },
            onInputSourceChange: { [weak inputService] in
                inputService?.handleInputSourceChange()
            }
        )

        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            activityBar.addItems([
                ActivityBarItem(
                    id: activityItemID,
                    title: metadata.name,
                    systemImage: "keyboard",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        self.activateInputWorkspace(
                            content: content,
                            chat: chat,
                            rootView: rootView,
                            toolbar: toolbar,
                            viewModel: viewModel
                        )
                    } else {
                        self.restoreInputWorkspace(
                            content: content,
                            chat: chat,
                            railView: railView,
                            rootView: rootView,
                            toolbar: toolbar
                        )
                    }
                },
            ])
        } else {
            // In compact hosts there is no ActivityBar event to drive the
            // workspace transition, so onBoot is the activation boundary.
            activateInputWorkspace(
                content: content,
                chat: chat,
                rootView: rootView,
                toolbar: toolbar,
                viewModel: viewModel
            )
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        eventObserver?.cancel()
        eventObserver = nil
        settingsObserver?.cancel()
        settingsObserver = nil
        viewModel = nil
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == activityItemID
        activityBar?.removeItems(ids: [activityItemID])
        if wasActive || activityBar == nil {
            restoreInputWorkspace(
                content: kernel.resolveProvider((any ContentViewProviding).self),
                chat: kernel.resolveProvider((any ChatSectionProviding).self),
                railView: kernel.resolveProvider((any RailViewProviding).self),
                rootView: kernel.resolveProvider((any RootViewProviding).self),
                toolbar: kernel.resolveProvider((any ToolbarProviding).self)
            )
        }
        InputPluginRuntimeBridge.dataRootDirectory = nil
        InputPluginRuntimeBridge.pluginDirectory = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    private func activateInputWorkspace(
        content: (any ContentViewProviding)?,
        chat: (any ChatSectionProviding)?,
        rootView: (any RootViewProviding)?,
        toolbar: (any ToolbarProviding)?,
        viewModel: InputSettingsViewModel
    ) {
        toolbar?.setVisibleCategories([.global, .system])
        content?.setContentView(AnyView(InputSettingsView(viewModel: viewModel)))
        chat?.setVisible(false)
        rootView?.setRailView(nil)
        rootView?.setRailViewVisible(false)
        rootView?.setContentHeaderViewHidden(true)
    }

    private func restoreInputWorkspace(
        content: (any ContentViewProviding)?,
        chat: (any ChatSectionProviding)?,
        railView: (any RailViewProviding)?,
        rootView: (any RootViewProviding)?,
        toolbar: (any ToolbarProviding)?
    ) {
        toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
        chat?.setVisible(true)
        rootView?.setRailView(railView?.makeRailView())
        rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
        rootView?.setContentHeaderViewHidden(false)
        content?.setContentView(nil)
    }
}
