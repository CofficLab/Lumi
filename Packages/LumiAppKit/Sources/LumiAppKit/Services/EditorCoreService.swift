import EditorTextView
import Foundation
import EditorService
import LumiCoreKit
import LumiPluginRegistry
import LumiUI
import SuperLogKit
import os

@MainActor
final class EditorCoreService: LumiEditorServicing, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.editor-core")
    nonisolated static let emoji = "📝"
    nonisolated static let verbose = false

    private let core: EditorCore
    private let themeRegistry: LumiUIThemeRegistry
    /// 由 `RootContainer` 在拿到 `LumiCore` 实例后注入;
    /// 注入前 `configureLifecycle` 走 `recentProjects()` 兜底。
    private var lumiCore: LumiCoreAccessing?
    private var pluginsChangedObserver: NSObjectProtocol?

    var editorService: EditorService { core.editorService }
    var extensionRegistry: EditorExtensionRegistry { core.extensionRegistry }

    var currentProjectPathProvider: (() -> String)? {
        get { core.currentProjectPathProvider }
        set { core.currentProjectPathProvider = newValue }
    }

    /// 由 `RootContainer` 在拿到 `LumiCore` 实例后调用,
    /// 把延迟注入的引用补上,并把 `EditorSettingsLifecycle.hostPersistenceRootURL`
    /// 切到 LumiCore 的 `dataRootDirectory`（即 v4.16.0 之前 `AppConfig.getDBFolderURL()`
    /// 所指的位置）。
    ///
    /// `configureLifecycle` 在 init 时已先于注入执行，但内部的 `provider` 闭包通过
    /// `self?.lumiCore?.projectComponent` 读，所以这里只更新引用 + 切换 persistence URL，
    /// 不需要重跑配置。
    func configure(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
        EditorSettingsLifecycle.hostPersistenceRootURL = { [weak lumiCore] in
            lumiCore?.storage.dataRootDirectory ?? Self.fallbackPersistenceRootURL
        }
    }

    private static var fallbackPersistenceRootURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }


    init(
        pluginService: PluginService,
        themeRegistry: LumiUIThemeRegistry = .shared,
        recentProjects: @escaping @Sendable () -> [ProjectEntry] = { [] }
    ) {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化 EditorCoreService")
        }

        self.themeRegistry = themeRegistry
        let core = EditorCore()
        core.extensionInstaller = { registry in
            await Self.registerEditorExtensions(
                into: registry,
                enabledPluginIDs: pluginService.enabledEditorExtensionPluginIDs
            )
        }
        self.core = core

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ EditorCore 创建完成")
        }

        EditorLanguageRuntimeBridge.configure = { context in
            await Self.configureEditorRuntime(context)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)配置生命周期")
        }
        configureLifecycle(
            recentProjects: recentProjects
        )

        core.reinstallExtensions()

        // 订阅系统外观（浅色/深色）变化：外观切换时把对应的编辑器语法主题同步给编辑器。
        // 原先由 RootContainer 接线，现在收回到 EditorCoreService 自管——它本来就持有
        // themeRegistry 且是 syncAppSyntaxThemes 的拥有者。
        themeRegistry.onSystemAppearanceDidChange = { [weak self] in
            self?.syncAppSyntaxThemes()
        }

        // 订阅插件启用状态变化：插件 enable/disable 后编辑器扩展集合会变，
        // 需要 reinstallExtensions 重建。原先由 RootContainer fan-out 调用，现在本类自治。
        pluginsChangedObserver = NotificationCenter.default.onLumiEnabledPluginsDidChange { [weak self] in
            self?.reinstallExtensions()
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ EditorCoreService 初始化完成")
        }
    }

    deinit {
        if let pluginsChangedObserver {
            NotificationCenter.default.removeObserver(pluginsChangedObserver)
        }
    }

    // MARK: - Editor Extensions Registration

    private static func registerEditorExtensions(
        into registry: EditorExtensionRegistry,
        enabledPluginIDs: Set<String>?
    ) async {
        let plugins = LumiPluginRegistry.plugins

        registry.uninstallAll()

        var records: [EditorInstalledPluginRecord] = []

        for pluginType in plugins {
            let info = pluginType.info
            let policy = pluginType.policy

            // 检查插件是否启用
            if let enabledPluginIDs {
                let isAlwaysOn = policy == .alwaysOn
                guard isAlwaysOn || enabledPluginIDs.contains(info.id) else { continue }
            }

            // 优先使用 LumiEditorExtensionRegistering 协议
            if let editorExtensionPlugin = pluginType as? (any LumiEditorExtensionRegistering.Type) {
                await editorExtensionPlugin.registerEditorExtensionsErased(into: registry)
            } else {
                await pluginType.registerEditorExtensions(into: registry)
            }

            // 记录已安装的插件
            if policy.isConfigurable {
                records.append(
                    EditorInstalledPluginRecord(
                        id: info.id,
                        displayName: info.displayName,
                        description: info.description,
                        order: info.order,
                        isConfigurable: policy.isConfigurable
                    )
                )
            }
        }

        registry.recordInstalledPlugins(records)
    }

    private static func configureEditorRuntime(_ context: PluginRuntimeContext) async {
        let plugins = LumiPluginRegistry.plugins

        for pluginType in plugins {
            await pluginType.configureEditorRuntime(context)
        }
    }

    // MARK: - Public Methods

    func reinstallExtensions() {
        if Self.verbose {
            Self.logger.info("\(Self.t)重新安装扩展")
        }
        core.reinstallExtensions()
    }

    func syncAppSyntaxThemes() {
        if Self.verbose {
            Self.logger.info("\(Self.t)同步编辑器语法主题")
        }
        EditorSettingsLifecycle.registerEditorThemeContributors?(extensionRegistry)
        let scheme = AppThemeAppearanceResolver.effectiveColorScheme
        let themeID = themeRegistry.resolvedEditorThemeId(colorScheme: scheme) ?? "xcode-dark"
        editorService.theme.syncInitialThemeFromExternal(themeID)
    }

    private func configureLifecycle(
        recentProjects: @escaping @Sendable () -> [ProjectEntry]
    ) {
        // 通过 LumiCore 获取项目列表
        let provider: () -> [ProjectEntry] = { [weak self] in
            self?.lumiCore?.projectComponent.projects ?? recentProjects()
        }

        // `hostPersistenceRootURL` 在 init 阶段尚无 LumiCore 实例，配置 `configure(lumiCore:)`
        // 后才会切到 LumiCore.dataRootDirectory 之上。期间若有 keybinding/config 读取，
        // 走 `bindingsFileURL` 的 `applicationSupportURL` 兜底分支。
        EditorSettingsLifecycle.onReinstallPlugins = { [weak self] registry in
            Task { @MainActor in
                guard let self else { return }
                if Self.verbose {
                    Self.logger.info("\(Self.t)重新安装插件扩展")
                }
                await self.core.extensionInstaller?(registry)
                self.core.editorService.state.refreshExtensionProviders()
            }
        }
        EditorSettingsLifecycle.editorThemeIDForAppThemeID = { [themeRegistry] _ in
            let scheme = AppThemeAppearanceResolver.effectiveColorScheme
            return themeRegistry.resolvedEditorThemeId(colorScheme: scheme) ?? "xcode-dark"
        }
        EditorSettingsLifecycle.registerEditorThemeContributors = { [themeRegistry] registry in
            EditorBuiltinSyntaxThemes.registerFallbacks(into: registry)
            EditorBuiltinSyntaxThemes.registerAppThemes(themeRegistry.themes, into: registry)
        }
        EditorSettingsLifecycle.registerMultiCursorTextView = { _, _ in
            // EditorMultiCursorCommandsPlugin 已弃用,多光标输入暂不安装。
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 生命周期配置完成")
        }
    }
}
