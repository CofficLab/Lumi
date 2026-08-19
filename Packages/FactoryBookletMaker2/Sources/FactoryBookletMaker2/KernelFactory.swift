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
import ProviderSettingView
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
    /// - `ProjectProviding` → `DefaultProjectProviding`
    /// - `ToastProviding` → `DefaultToastProviding`（no-op）
    /// - `NetworkProviding` → `DefaultNetworkProviding`（URLSession）
    /// - `ToolbarProviding` → `DefaultToolbarProviding`（按 placement 渲染）
    /// - `RootViewProviding` → `DefaultRootViewProviding`（工具栏 + 内容区）
    /// - `ActivityBarProviding` → `DefaultActivityBarProviding`（竖直入口栏）
    /// - `RailViewProviding` → `DefaultRailViewProviding`（侧边栏标签 + 内容）
    /// - `SettingViewProviding` → `DefaultSettingViewProviding`（入口 + 详情）
    ///
    /// 插件启动前通过 `pluginManaging` 过滤：只有用户启用的插件才会被启动，
    /// 被用户禁用的插件不会注册到内核。
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
        // 从插件工厂拿到全部插件，通过 PluginManaging 过滤出用户启用的，再注册到内核。
        let allPlugins = DefaultPluginFactory().makePlugins()
        let enabledPlugins = pluginManaging.enabledPlugins(from: allPlugins)
        try kernel.start(plugins: enabledPlugins)
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

        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            return AnyView(Text("RootViewProviding not registered"))
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

    // MARK: - Settings View Assembly

    /// 创建内核并返回设置视图。
    ///
    /// 设置视图的入口由已启动的插件（如 SettingGeneralPlugin）贡献；
    /// 宿主只需把返回的视图放进设置窗口（如 `Window("设置")`）即可。
    ///
    /// - Returns: 已装配的设置视图（`AnyView`）。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeSettingsView() throws -> AnyView {
        let kernel = try makeKernel()

        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            return AnyView(Text("SettingViewProviding not registered"))
        }

        return settings.makeSettingView()
    }
}
