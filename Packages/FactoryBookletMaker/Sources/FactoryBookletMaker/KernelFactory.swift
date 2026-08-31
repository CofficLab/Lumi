import Foundation
import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderNetwork
import ProviderPluginManaging
import ProviderProject
import ProviderRailView
import ProviderRootView
import ProviderStorage
import ProviderToast
import ProviderToolbar
import SwiftUI

/// KernelFactory — 内核工厂。
///
/// 负责创建 KernelCore 内核，内部通过 `DefaultProviderFactory` 装配各 Provider
/// （Project / Toast / Network / Toolbar / RootView / ActivityBar / RailView /
/// SettingView），并通过 `start(plugins:)` 启动插件（如 SettingGeneralPlugin）
/// 注册各自的贡献。
@MainActor
public enum KernelFactory {

    /// 创建 KernelCore 内核，装配并注册全部默认 Provider：
    /// - `StorageProviding` → `DefaultStorageProvider`（Application Support 磁盘存储）
    /// - `ContentViewProviding` → `DefaultContentViewProviding`（当前内容视图）
    /// - `ProjectProviding` → `DefaultProjectProvider`
    /// - `ToastProviding` → `DefaultToastProviding`（no-op）
    /// - `NetworkProviding` → `DefaultNetworkProviding`（URLSession）
    /// - `ToolbarProviding` → `DefaultToolbarProviding`（按 placement 渲染）
    /// - `RootViewProviding` → `DefaultRootViewProviding`（工具栏 + 内容区）
    /// - `ActivityBarProviding` → `DefaultActivityBarProviding`（竖直入口栏）
    /// - `RailViewProviding` → `DefaultRailViewProviding`（侧边栏标签 + 内容）
    /// - `SettingViewProviding` → `DefaultSettingViewProviding`（入口 + 详情）
    ///
    /// 插件启动前通过 `pluginManaging` 过滤。BookletMaker 是该专用宿主的
    /// 必需功能，插件元数据标记为 `.alwaysOn`，不会被过滤掉。
    ///
    /// - Parameter pluginManaging: 插件管理器，用于判断哪些插件应当启动。
    ///   默认使用 `DefaultPluginManager()`（无持久化状态时所有可配置插件按默认策略启动）。
    /// - Returns: 已装配默认 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel(
        pluginManaging: any PluginManaging = DefaultPluginManager()
    ) throws -> KernelCoreContainer {
        let kernel = KernelCoreContainer()
        try DefaultProviderFactory().registerProviders(into: kernel)
        // 将完整插件目录注册到内核。禁用插件不会 Boot，但仍可通过 onRegister
        // 贡献提示词等目录型能力。
        let allPlugins = DefaultPluginFactory().makePlugins()
        _ = pluginManaging
        try kernel.start(plugins: allPlugins)
        return kernel
    }

    // MARK: - Main View Assembly

    /// 创建内核并组装完整主视图（工具栏 + ActivityBar + Rail + 内容区）。
    ///
    /// 视图组装逻辑集中在此：宿主只需要一个视图，无需关心内核如何把
    /// 各 Provider 的能力组合起来。
    ///
    /// - Returns: 已装配的根视图（`AnyView`）。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeMainView() throws -> AnyView {
        let kernel = try makeKernel()
        return try makeMainView(kernel: kernel)
    }

    /// 使用既有内核组装主视图，供主窗口与设置窗口共享同一插件与持久化状态。
    public static func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {

        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            return AnyView(Text(LumiPluginLocalization.string("RootViewProviding not registered", bundle: .module)))
        }

        if let toolbar = kernel.resolveProvider((any ToolbarProviding).self) {
            rootView.setToolbarView(toolbar.makeToolbarView())
        }
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            rootView.setActivityBarView(activityBar.makeActivityBarView())
        }
        if let rail = kernel.resolveProvider((any RailViewProviding).self) {
            rootView.setRailView(rail.makeRailView())
        }
        if let contentView = kernel.resolveProvider((any ContentViewProviding).self) {
            rootView.setContentView(contentView.makeContentView())
        }
        return rootView.makeRootView()
    }
}
