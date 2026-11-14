import KernelCore
import PluginActivityBar
import PluginAppIconDesigner
import PluginCommand
import PluginLogoCoffic
import PluginLogoManager
import PluginSettingGeneral
import PluginSettingView
import PluginStorage
import PluginThemePack
import PluginThemeManager
import PluginToolManager

/// AppIconDesigner 的专用插件目录。
///
/// 与 BookletMaker 使用相同的基础宿主插件，额外保留图标设计器运行所需的
/// 工具管理与通用设置能力；不会加载 Lumi 的 LLM、Agent、项目编辑器等插件。
@MainActor
public struct DefaultPluginFactory: PluginFactory {
    public init() {}

    public func makePlugins() -> [any SuperPlugin] {
        var plugins: [any SuperPlugin] = []
        if let storage = StorageSuperPlugin.makeIfAvailable() {
            plugins.append(storage)
        }
        plugins += [
            CommandPlugin(),
            PluginSettingView(id: "com.coffic.lumi.plugin.setting-view"),
            PluginLogoManager(),
            PluginToolManager(),
            PluginActivityBar(),
            SettingGeneralPlugin(),
            LogoCofficPlugin(),
            ThemeManagerPlugin(),
            ThemePackPlugin(),
            AlwaysOnPlugin(AppIconDesignerPlugin()),
        ]
        return plugins
    }
}

/// 在专用宿主需要时，按显式 allow-list 选择插件。
@MainActor
public struct SelectedPluginFactory: PluginFactory {
    private let base: any PluginFactory
    public let allowedPluginIDs: Set<String>

    public init(allowedPluginIDs: Set<String>) {
        self.allowedPluginIDs = allowedPluginIDs
        self.base = DefaultPluginFactory()
    }

    public init(allowedPluginIDs: Set<String>, base: any PluginFactory) {
        self.allowedPluginIDs = allowedPluginIDs
        self.base = base
    }

    public func makePlugins() -> [any SuperPlugin] {
        base.makePlugins().filter { allowedPluginIDs.contains($0.id) }
    }
}

/// 仅改变专用宿主中的启用策略；所有生命周期与贡献仍由原插件实现。
@MainActor
private final class AlwaysOnPlugin: SuperPlugin {
    private let wrapped: any SuperPlugin

    init(_ wrapped: any SuperPlugin) {
        self.wrapped = wrapped
    }

    var id: String { wrapped.id }
    var order: Int { wrapped.order }
    var dependencies: [String] { wrapped.dependencies }
    var metadata: PluginMetadata {
        PluginMetadata(
            id: wrapped.metadata.id,
            name: wrapped.metadata.name,
            description: wrapped.metadata.description,
            version: wrapped.metadata.version,
            category: wrapped.metadata.category,
            stage: wrapped.metadata.stage,
            policy: .alwaysOn,
            permissions: wrapped.metadata.permissions
        )
    }

    func onBoot(kernel: KernelCoreContainer) throws { try wrapped.onBoot(kernel: kernel) }
    func onReady(kernel: KernelCoreContainer) throws { try wrapped.onReady(kernel: kernel) }
    func onShutdown(kernel: KernelCoreContainer) throws { try wrapped.onShutdown(kernel: kernel) }
    func onEnable(kernel: KernelCoreContainer) async throws { try await wrapped.onEnable(kernel: kernel) }
    func onDisable(kernel: KernelCoreContainer) async throws { try await wrapped.onDisable(kernel: kernel) }
    // 包装只改启用策略，注册钩子也必须转发：插件在 onRegister/onUnregister
    // 注入/撤回 About 与 Manual 文档，漏转会让独立 App 永远缺关于页与说明书（#321）。
    func onRegister(kernel: KernelCoreContainer) throws { try wrapped.onRegister(kernel: kernel) }
    func onUnregister(kernel: KernelCoreContainer) throws { try wrapped.onUnregister(kernel: kernel) }
}
