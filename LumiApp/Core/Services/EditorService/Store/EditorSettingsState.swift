import Combine
import CoreGraphics
import Foundation

/// 编辑器设置的作用域选择枚举
/// 定义了三种设置作用域：全局、工作区、语言特定
enum EditorSettingsScopeSelection: String, CaseIterable, Identifiable {
    case global
    case workspace
    case language

    var id: String { rawValue }

    var title: String {
        switch self {
        case .global: return "Global"
        case .workspace: return "Workspace"
        case .language: return "Language"
        }
    }
}

/// 编辑器设置状态管理类
/// 负责管理编辑器的所有配置项，包括全局设置和作用域特定的覆盖设置
/// 使用单例模式，确保整个应用中只有一个实例
@MainActor
final class EditorSettingsState: ObservableObject {
    // MARK: - 单例实例
    static let shared = EditorSettingsState()

    // MARK: - 全局设置属性
    
    /// 编辑器字体大小（单位：磅）
    @Published var fontSize: Double = 13.0 { didSet { persistIfNeeded() } }
    
    /// Tab 键对应的空格数
    @Published var tabWidth: Int = 4 { didSet { persistIfNeeded() } }
    
    /// 是否使用空格代替 Tab 字符
    @Published var useSpaces: Bool = true { didSet { persistIfNeeded() } }
    
    /// 是否启用自动换行
    @Published var wrapLines: Bool = true { didSet { persistIfNeeded() } }
    
    /// 是否显示代码缩略图（minimap）
    @Published var showMinimap: Bool = true { didSet { persistIfNeeded() } }
    
    /// 是否显示行号区域（gutter）
    @Published var showGutter: Bool = true { didSet { persistIfNeeded() } }
    
    /// 是否显示代码折叠带
    @Published var showFoldingRibbon: Bool = true { didSet { persistIfNeeded() } }
    
    /// 保存时是否自动格式化代码
    @Published var formatOnSave: Bool = false { didSet { persistIfNeeded() } }
    
    /// 保存时是否自动整理 import 语句
    @Published var organizeImportsOnSave: Bool = false { didSet { persistIfNeeded() } }
    
    /// 保存时是否自动修复所有可自动修复的问题
    @Published var fixAllOnSave: Bool = false { didSet { persistIfNeeded() } }
    
    /// 保存时是否自动删除行尾空白字符
    @Published var trimTrailingWhitespaceOnSave: Bool = true { didSet { persistIfNeeded() } }
    
    /// 保存时是否自动在文件末尾添加换行符
    @Published var insertFinalNewlineOnSave: Bool = true { didSet { persistIfNeeded() } }

    // MARK: - 作用域选择相关属性
    
    /// 当前选择的设置作用域（全局/工作区/语言）
    @Published var selectedScope: EditorSettingsScopeSelection = .global { didSet { restoreScopedOverrideDraft() } }
    
    /// 当前选择的语言 ID（当作用域为语言特定时使用）
    @Published var selectedLanguageID: String = "swift" { didSet { restoreScopedOverrideDraft() } }

    // MARK: - 作用域特定覆盖设置
    
    /// 是否启用作用域特定的 Tab 宽度覆盖
    @Published var scopedTabWidthEnabled: Bool = false { didSet { persistScopedOverrideIfNeeded() } }
    
    /// 作用域特定的 Tab 宽度值
    @Published var scopedTabWidth: Int = 4 { didSet { persistScopedOverrideIfNeeded() } }
    
    /// 是否启用作用域特定的空格/Tab 设置覆盖
    @Published var scopedUseSpacesEnabled: Bool = false { didSet { persistScopedOverrideIfNeeded() } }
    
    /// 作用域特定的是否使用空格设置
    @Published var scopedUseSpaces: Bool = true { didSet { persistScopedOverrideIfNeeded() } }
    
    /// 是否启用作用域特定的自动换行设置覆盖
    @Published var scopedWrapLinesEnabled: Bool = false { didSet { persistScopedOverrideIfNeeded() } }
    
    /// 作用域特定的自动换行设置
    @Published var scopedWrapLines: Bool = true { didSet { persistScopedOverrideIfNeeded() } }
    
    /// 是否启用作用域特定的保存时格式化设置覆盖
    @Published var scopedFormatOnSaveEnabled: Bool = false { didSet { persistScopedOverrideIfNeeded() } }
    
    /// 作用域特定的保存时格式化设置
    @Published var scopedFormatOnSave: Bool = false { didSet { persistScopedOverrideIfNeeded() } }

    // MARK: - 功能支持标志
    
    /// 是否支持渲染空白字符（当前版本暂不支持）
    let supportsRenderWhitespace = false

    // MARK: - 私有依赖和状态
    
    /// 配置控制器，负责配置的持久化和恢复
    private let configController: EditorConfigController
    
    /// 插件管理器，负责管理编辑器插件
    private let pluginManager: EditorPluginManager
    
    /// 当前工作区路径提供者（由插件注入，内核不关心项目概念）
    let currentWorkspacePathProvider: (() -> String?)?
    
    /// 基础配置快照，用于存储和恢复全局设置
    private var baseSnapshot: EditorConfigSnapshot
    
    /// 是否抑制持久化操作（在批量更新时使用）
    private var suppressPersistence = true
    
    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化方法
    
    /// 初始化编辑器设置状态
    /// - Parameters:
    ///   - configController: 配置控制器实例
    ///   - pluginManager: 插件管理器实例
    ///   - currentWorkspacePathProvider: 工作区路径提供者闭包
    init(
        configController: EditorConfigController = EditorConfigController(),
        pluginManager: EditorPluginManager = EditorPluginManager(),
        currentWorkspacePathProvider: (() -> String?)? = nil
    ) {
        self.configController = configController
        self.pluginManager = pluginManager
        self.currentWorkspacePathProvider = currentWorkspacePathProvider
        self.baseSnapshot = configController.restoreConfig(clampedSidePanelWidth: { CGFloat($0) })

        // 恢复保存的设置
        restore()
        // 重新安装编辑器插件
        reinstallEditorPlugins()
        // 监听插件设置变化
        observePluginSettingChanges()
    }

    // MARK: - 计算属性
    
    /// 获取插件贡献的设置项列表
    var contributedSettings: [EditorSettingsItemSuggestion] {
        pluginManager.registry.settingsSuggestions(state: self)
    }

    /// 获取当前工作区路径
    var currentWorkspacePath: String? {
        currentWorkspacePathProvider?()
    }

    /// 获取所有可用的语言 ID 列表
    var availableLanguageIDs: [String] {
        EditorLanguageID.all
    }

    /// 是否可以编辑作用域特定的覆盖设置
    /// 只有当选择了非全局作用域时才可编辑
    var canEditScopedOverrides: Bool {
        activeOverrideScope != nil
    }

    /// 获取当前作用域的描述标签
    /// 用于在设置界面中显示当前作用域的说明
    var activeOverrideScopeLabel: String {
        switch selectedScope {
        case .global:
            return "Global settings apply to every editor."
        case .workspace:
            return currentWorkspacePath ?? "Open a workspace to edit workspace overrides."
        case .language:
            return selectedLanguageID
        }
    }

    // MARK: - 公共方法
    
    /// 从持久化存储恢复所有设置
    /// 在初始化时调用，或手动刷新设置时调用
    func restore() {
        suppressPersistence = true
        let snapshot = configController.restoreConfig(clampedSidePanelWidth: { CGFloat($0) })
        baseSnapshot = snapshot
        
        // 恢复全局设置
        fontSize = snapshot.fontSize
        tabWidth = snapshot.tabWidth
        useSpaces = snapshot.useSpaces
        wrapLines = snapshot.wrapLines
        showMinimap = snapshot.showMinimap
        showGutter = snapshot.showGutter
        showFoldingRibbon = snapshot.showFoldingRibbon
        formatOnSave = snapshot.formatOnSave
        organizeImportsOnSave = snapshot.organizeImportsOnSave
        fixAllOnSave = snapshot.fixAllOnSave
        trimTrailingWhitespaceOnSave = snapshot.trimTrailingWhitespaceOnSave
        insertFinalNewlineOnSave = snapshot.insertFinalNewlineOnSave
        
        // 恢复作用域特定的覆盖设置
        restoreScopedOverrideDraft()
        suppressPersistence = false
    }

    // MARK: - 私有方法
    
    /// 创建当前设置的快照
    /// 用于持久化和通知其他组件设置变化
    private var snapshot: EditorConfigSnapshot {
        EditorConfigSnapshot(
            fontSize: fontSize,
            tabWidth: tabWidth,
            useSpaces: useSpaces,
            formatOnSave: formatOnSave,
            organizeImportsOnSave: organizeImportsOnSave,
            fixAllOnSave: fixAllOnSave,
            trimTrailingWhitespaceOnSave: trimTrailingWhitespaceOnSave,
            insertFinalNewlineOnSave: insertFinalNewlineOnSave,
            wrapLines: wrapLines,
            showMinimap: showMinimap,
            showGutter: showGutter,
            showFoldingRibbon: showFoldingRibbon,
            currentThemeId: baseSnapshot.currentThemeId,
            sidePanelWidth: baseSnapshot.sidePanelWidth
        )
    }

    /// 如果需要，持久化全局设置
    /// 在设置属性变化时自动调用
    private func persistIfNeeded() {
        guard !suppressPersistence else { return }
        refreshExternalSnapshotFields()
        let snapshot = snapshot
        configController.persistConfig(snapshot)
        
        // 通知其他组件设置已变化
        NotificationCenter.default.post(
            name: .lumiEditorSettingsDidChange,
            object: self,
            userInfo: ["snapshot": snapshot]
        )
    }

    /// 如果需要，持久化作用域特定的覆盖设置
    /// 在作用域覆盖设置属性变化时自动调用
    private func persistScopedOverrideIfNeeded() {
        guard !suppressPersistence,
              let scope = activeOverrideScope else { return }
        
        configController.persistOverrideSnapshot(
            currentScopedOverrideSnapshot,
            for: scope,
            clampedSidePanelWidth: { CGFloat($0) }
        )
        
        // 通知其他组件设置已变化
        NotificationCenter.default.post(
            name: .lumiEditorSettingsDidChange,
            object: self,
            userInfo: ["snapshot": snapshot]
        )
    }

    /// 重新安装编辑器插件
    /// 当插件列表或启用状态变化时调用
    private func reinstallEditorPlugins() {
        let plugins = PluginVM.shared.plugins.filter {
            PluginVM.shared.isPluginEnabled($0) && $0.providesEditorExtensions
        }
        pluginManager.install(plugins: plugins)
        objectWillChange.send()
    }

    /// 监听插件设置变化事件
    /// 当插件设置变化时，重新安装插件
    private func observePluginSettingChanges() {
        NotificationCenter.default.publisher(for: .pluginSettingsChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reinstallEditorPlugins()
            }
            .store(in: &cancellables)
    }

    /// 刷新外部快照字段
    /// 从配置控制器获取最新的主题 ID 和侧边栏宽度
    private func refreshExternalSnapshotFields() {
        let latest = configController.restoreConfig(clampedSidePanelWidth: { CGFloat($0) })
        baseSnapshot.currentThemeId = latest.currentThemeId
        baseSnapshot.sidePanelWidth = latest.sidePanelWidth
    }

    /// 获取当前激活的覆盖作用域
    /// 根据用户选择的作用域类型返回对应的配置覆盖作用域
    private var activeOverrideScope: EditorConfigOverrideScope? {
        switch selectedScope {
        case .global:
            return nil
        case .workspace:
            guard let currentWorkspacePath else { return nil }
            return .workspace(currentWorkspacePath)
        case .language:
            return .language(selectedLanguageID)
        }
    }

    /// 获取当前作用域特定的覆盖设置快照
    /// 只包含用户明确启用的覆盖设置
    private var currentScopedOverrideSnapshot: EditorScopedOverrideSnapshot {
        EditorScopedOverrideSnapshot(
            tabWidth: scopedTabWidthEnabled ? scopedTabWidth : nil,
            useSpaces: scopedUseSpacesEnabled ? scopedUseSpaces : nil,
            wrapLines: scopedWrapLinesEnabled ? scopedWrapLines : nil,
            formatOnSave: scopedFormatOnSaveEnabled ? scopedFormatOnSave : nil
        )
    }

    /// 恢复作用域特定的覆盖设置草稿
    /// 当用户切换作用域或语言时，加载对应的覆盖设置
    private func restoreScopedOverrideDraft() {
        suppressPersistence = true
        let overrideSnapshot: EditorScopedOverrideSnapshot
        if let scope = activeOverrideScope {
            overrideSnapshot = configController.overrideSnapshot(
                for: scope,
                clampedSidePanelWidth: { CGFloat($0) }
            )
        } else {
            overrideSnapshot = EditorScopedOverrideSnapshot()
        }

        // 恢复各覆盖设置项
        scopedTabWidthEnabled = overrideSnapshot.tabWidth != nil
        scopedTabWidth = overrideSnapshot.tabWidth ?? baseSnapshot.tabWidth
        scopedUseSpacesEnabled = overrideSnapshot.useSpaces != nil
        scopedUseSpaces = overrideSnapshot.useSpaces ?? baseSnapshot.useSpaces
        scopedWrapLinesEnabled = overrideSnapshot.wrapLines != nil
        scopedWrapLines = overrideSnapshot.wrapLines ?? baseSnapshot.wrapLines
        scopedFormatOnSaveEnabled = overrideSnapshot.formatOnSave != nil
        scopedFormatOnSave = overrideSnapshot.formatOnSave ?? baseSnapshot.formatOnSave
        suppressPersistence = false
    }
}
