import Foundation
import KernelCore
import ProviderExternalFile
import ProviderProject
import ProviderChatSection
import ProviderConversation
import SwiftUI

/// KernelFactory — 内核工厂。
///
/// 负责创建 KernelCore 内核，内部通过 `DefaultProviderFactory` 装配各 Provider
/// （Project / Toast / Network / Toolbar / RootView / ActivityBar / RailView /
/// SettingView），并通过 `start(plugins:)` 启动插件（如 SettingGeneralPlugin）
/// 注册各自的贡献。
///
/// 视图组装（主视图 / 设置视图 / LumiUI 主题桥接）由 `ViewFactory` 完成；
/// `KernelFactory` 的便捷入口委托 `DefaultViewFactory`，宿主可通过
/// `makeMainView(kernel:viewFactory:)` / `makeSettingsView(kernel:viewFactory:)`
/// 传入自定义 `ViewFactory` 覆盖视图组装逻辑。
@MainActor
public enum KernelFactory {
    /// Routes a path received from Finder, Dock, Launch Services, or the URL
    /// scheme through the V2 providers. Directories retain the legacy meaning
    /// of switching the current project; files are offered to registered V2
    /// external-file handlers (for example DatabaseManager).
    @discardableResult
    public static func openExternalPath(
        _ path: String,
        kernel: KernelCoreContainer
    ) async -> Bool {
        let normalizedPath = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        guard !normalizedPath.isEmpty,
              FileManager.default.fileExists(atPath: normalizedPath) else {
            return false
        }

        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: normalizedPath, isDirectory: &isDirectory)
        if isDirectory.boolValue {
            guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
                return false
            }
            do {
                try await project.openProject(at: normalizedPath)
                return true
            } catch {
                return false
            }
        }

        return kernel.resolveProvider((any ExternalFileOpening).self)?.open(
            URL(fileURLWithPath: normalizedPath)
        ) ?? false
    }

    /// 创建 KernelCore 内核，装配并注册全部默认 Provider
    ///
    /// - Returns: 已装配默认 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel(
        additionalPlugins: [any SuperPlugin] = []
    ) throws -> KernelCoreContainer {
        try makeKernel(
            providerFactory: DefaultProviderFactory(),
            pluginFactory: DefaultPluginFactory(),
            additionalPlugins: additionalPlugins
        )
    }

    /// 异步插件目录的装配入口。
    ///
    /// 现有轻量插件可以继续使用同步 `makeKernel`；需要数据库迁移、进程启动、
    /// Language Server 或网络准备的插件应由宿主通过本入口启动，确保其
    /// `AsyncSuperPlugin` 生命周期不会被跳过。
    public static func makeKernelAsync(
        additionalPlugins: [any SuperPlugin] = []
    ) async throws -> KernelCoreContainer {
        try await makeKernelAsync(
            providerFactory: DefaultProviderFactory(),
            pluginFactory: DefaultPluginFactory(),
            additionalPlugins: additionalPlugins
        )
    }

    public static func makeKernelAsync(
        providerFactory: any ProviderFactory,
        pluginFactory: any PluginFactory,
        additionalPlugins: [any SuperPlugin] = []
    ) async throws -> KernelCoreContainer {
        // 复用同一套 Provider composition；空目录先把内核推进 running，随后
        // `startAsync` 原子安装真实目录。后续宿主切换为异步启动时无需复制装配图。
        let kernel = try makeKernel(
            providerFactory: providerFactory,
            pluginFactory: EmptyPluginFactory(),
            additionalPlugins: []
        )
        // 将完整插件目录交给 Kernel 注册；Kernel 会对禁用插件跳过 Boot/Ready，
        // 但仍执行 onRegister，以便贡献提示词等目录型能力。
        try await kernel.startAsync(plugins: pluginFactory.makePlugins() + additionalPlugins)
        return kernel
    }

    /// 使用宿主提供的 Provider / Plugin 工厂装配内核。
    ///
    /// Provider 的创建与注册全部委托给 `providerFactory.registerProviders(into:)`；
    /// 本方法只负责创建容器、启动插件并完成插件启动后的视图绑定。
    public static func makeKernel(
        providerFactory: any ProviderFactory,
        pluginFactory: any PluginFactory,
        additionalPlugins: [any SuperPlugin] = []
    ) throws -> KernelCoreContainer {
        let kernel = KernelCoreContainer()
        try providerFactory.registerProviders(into: kernel)

        // 默认目录与宿主附加插件在同一个依赖图中统一校验、排序、原子启动。
        // 后续复刻插件只需由 App/专用 Factory 传入，不必继续修改内核工厂。
        // 将完整插件目录交给 Kernel 注册；Kernel 会对禁用插件跳过 Boot/Ready，
        // 但仍执行 onRegister，以便贡献提示词等目录型能力。
        try kernel.start(plugins: pluginFactory.makePlugins() + additionalPlugins)

        // header / toolbar 可见性绑定（复刻旧版 ChatView 语义：无选中会话时
        // 隐藏 header / toolbar，仅保留正文与输入区）。
        // 必须在插件启动完成后执行：此时 ConversationManaging 已是最终实例
        // （PluginConversationManager order=7 可能已替换默认内存实现）。
        if let chat = kernel.resolveProvider((any ChatSectionProviding).self),
           let conversations = kernel.resolveProvider((any ConversationManaging).self) {
            chat.bindConversationSelection(conversations)
        }

        return kernel
    }

    // MARK: - Main View Assembly

    /// 创建内核并组装完整主视图（工具栏 + ActivityBar + Rail + 内容区）。
    ///
    /// 视图组装逻辑由 `ViewFactory` 完成（默认 `DefaultViewFactory`）；
    /// 宿主只需要一个视图，无需关心内核如何把各 Provider 的能力组合起来。
    /// 返回的视图应用了当前选中主题（明暗外观 + 背景色）。
    ///
    /// - Returns: 已装配的根视图（`AnyView`）。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeMainView() throws -> AnyView {
        try makeMainView(kernel: makeKernel())
    }

    /// 使用已装配的内核组装主视图（共享内核时使用）。
    ///
    /// 宿主传入自己持有的 `KernelCoreContainer`，使主窗口 / 设置窗口 /
    /// 菜单栏共享同一内核与同一 `ThemeProviding`，主题切换即时同步。
    /// 视图组装委托 `DefaultViewFactory`。
    public static func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        try makeMainView(kernel: kernel, viewFactory: DefaultViewFactory())
    }

    /// 使用自定义 `ViewFactory` 组装主视图（覆盖视图组装逻辑时使用）。
    ///
    /// - Parameter viewFactory: 自定义 `ViewFactory` 实现；默认行为见
    ///   `DefaultViewFactory.makeMainView(kernel:)`。
    public static func makeMainView(
        kernel: KernelCoreContainer,
        viewFactory: any ViewFactory
    ) throws -> AnyView {
        try viewFactory.makeMainView(kernel: kernel)
    }

    // MARK: - Settings View Assembly

    /// 创建内核并返回设置视图。
    ///
    /// 设置视图的入口由已启动的插件（如 SettingGeneralPlugin）贡献；
    /// 宿主只需把返回的视图放进设置窗口（如 `Window("设置")`）即可。
    ///
    /// 侧边栏顶部 Logo 由设置实现（如 `PluginSettingView`）作为内部行为自行渲染，
    /// 此入口不再负责 Logo 注入，仅返回已装配的设置视图。
    ///
    /// - Returns: 已装配的设置视图（`AnyView`）。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeSettingsView() throws -> AnyView {
        try makeSettingsView(kernel: makeKernel())
    }

    /// 使用已装配的内核返回设置视图（共享内核时使用）。
    /// 视图组装委托 `DefaultViewFactory`。
    public static func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        try makeSettingsView(kernel: kernel, viewFactory: DefaultViewFactory())
    }

    /// 使用自定义 `ViewFactory` 组装设置视图（覆盖视图组装逻辑时使用）。
    public static func makeSettingsView(
        kernel: KernelCoreContainer,
        viewFactory: any ViewFactory
    ) throws -> AnyView {
        try viewFactory.makeSettingsView(kernel: kernel)
    }
}

@MainActor
private struct EmptyPluginFactory: PluginFactory {
    func makePlugins() -> [any SuperPlugin] { [] }
}
