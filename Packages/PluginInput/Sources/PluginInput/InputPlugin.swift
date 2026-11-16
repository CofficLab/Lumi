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

        let viewModel = InputSettingsViewModel()
        self.viewModel = viewModel
        installRuntimeContributions(kernel: kernel, viewModel: viewModel)
    }

    /// 运行时启用：重新安装监听器与 ActivityBar 入口。
    ///
    /// 启动时被跳过、从未 Boot 的插件走 `onBoot` 完整初始化；曾 Boot 过
    /// 再启用的插件只走本方法。viewModel 与运行时目录在禁用期间保持存活。
    public func onEnable(kernel: KernelCoreContainer) async throws {
        guard let viewModel else { return }
        installRuntimeContributions(kernel: kernel, viewModel: viewModel)
    }

    /// 运行时禁用：停止应用激活监听并撤回入口。
    ///
    /// 内核在运行时禁用插件时**不会**调用 `onShutdown`，也不会代撤 Provider 侧
    /// 贡献。`InputEventObserver` 仍订阅 `NSWorkspace.didActivateApplicationNotification`，
    /// 把激活转发给 `InputService.handleAppActivation`；后者只检查业务开关
    /// `config.isEnabled`，不知道插件生命周期，因此禁用后仍会按旧规则切换
    /// macOS 输入源（见 issue #365）。禁用必须立即取消监听，启用时再恢复。
    public func onDisable(kernel: KernelCoreContainer) async throws {
        removeRuntimeContributions(kernel: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        removeRuntimeContributions(kernel: kernel)
        viewModel = nil
        InputPluginRuntimeBridge.dataRootDirectory = nil
        InputPluginRuntimeBridge.pluginDirectory = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    /// 安装运行时贡献：设置/事件监听器与 ActivityBar 入口（或紧凑宿主激活）。
    /// 幂等：重复安装前先取消既有监听器，避免重复订阅。
    private func installRuntimeContributions(
        kernel: KernelCoreContainer,
        viewModel: InputSettingsViewModel
    ) {
        let inputService = InputService.shared
        settingsObserver?.cancel()
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

    /// 撤回运行时贡献：取消监听器、移除 ActivityBar 入口并恢复工作区。
    /// 保留 viewModel 与运行时目录，供 `onEnable` 恢复。
    private func removeRuntimeContributions(kernel: KernelCoreContainer) {
        eventObserver?.cancel()
        eventObserver = nil
        settingsObserver?.cancel()
        settingsObserver = nil
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
    }

    /// 事件监听器是否仍在订阅系统通知。仅供单元测试断言禁用生命周期。
    var isEventObserverRunningForTesting: Bool {
        eventObserver?.isObservingForTesting ?? false
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
