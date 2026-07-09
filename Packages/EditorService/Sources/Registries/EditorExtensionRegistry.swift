import Foundation
import EditorSource
import EditorTextView
import SwiftUI
import SuperLogKit
import os

/// 编辑器扩展注册中心
/// 同时承担原 `EditorPluginManager` 的插件安装职责：
/// - 维护 `installedPlugins` 列表（按 order 排序）
/// - 提供 `installPlugins` / `uninstallAll` 方法
///
/// ## 线程说明
/// - 注册/注销：@MainActor（与 View 生命周期一致）
/// - 同步查询（command/sheet/toolbar）：@MainActor
/// - 异步查询（completion/hover/codeAction）：委托给 `ExtensionResolver`（后台 actor）执行，
///   但保留当前同步版本以确保向后兼容。调用方可选择使用 `resolveCompletionAsync` 等方法
///   将聚合和去重放到后台线程。
@MainActor
public final class EditorExtensionRegistry: ObservableObject, SuperLog {
    private static let logger = os.Logger(subsystem: EditorHostEnvironment.current.logSubsystem, category: "editor.ext-registry")
    nonisolated public static let verbose = false
    nonisolated public static let emoji = "🔌"

    /// 已安装的编辑器插件（按 order 排序）
    @Published public private(set) var installedPlugins: [EditorInstalledPluginRecord] = []

    /// 记录已安装的编辑器插件（由 RootViewContainer 在插件自注册后调用）
    ///
    /// 注意：此方法仅用于记录 installedPlugins 列表，不再调用 registerEditorExtensions。
    /// 插件的自注册应由调用方在调用此方法前完成。
    public func recordInstalledPlugins(_ records: [EditorInstalledPluginRecord]) {
        // ⚠️ 不调用 reset()——注册阶段（registerEditorExtensions）已在之前完成，
        // reset() 会清空所有已注册的 contributors（commandContributors、hoverContributors 等）。
        // 仅清空 installedPlugins 列表本身再重新填充。
        installedPlugins.removeAll()

        // Sort by order, then by id
        let sorted = records.sorted { a, b in
            if a.order != b.order {
                return a.order < b.order
            }
            return a.id.localizedCaseInsensitiveCompare(b.id) == .orderedAscending
        }

        installedPlugins = sorted

        if Self.verbose {
                    Self.logger.info("\(self.t)recordInstalledPlugins: 记录 \(sorted.count) 个插件, ids=\(sorted.map(\.id))")
        }
    }

    /// 卸载所有已安装的编辑器插件
    public func uninstallAll() {
        reset()
        if Self.verbose {
                    Self.logger.info("\(self.t)已卸载所有编辑器插件")
        }
    }

    // MARK: - Contributor Storage

    private var completionContributors: [any SuperEditorCompletionContributor] = []
    private var hoverContributors: [any SuperEditorHoverContributor] = []
    private var hoverContentContributors: [any SuperEditorHoverContentContributor] = []
    private var codeActionContributors: [any SuperEditorCodeActionContributor] = []
    private var highlightProviderContributors: [any SuperEditorHighlightProviderContributor] = []
    private var cachedHighlightProvidersByLanguageID: [String: [any HighlightProviding]] = [:]
    private var commandContributors: [any SuperEditorCommandContributor] = []
    private var contextMenuContributors: [any SuperEditorContextMenuContributor] = []
    private var gutterDecorationContributors: [any SuperEditorGutterDecorationContributor] = []
    private var panelContributors: [any SuperEditorPanelContributor] = []
    private var settingsContributors: [any SuperEditorSettingsContributor] = []
    private var statusItemContributors: [any SuperEditorStatusItemContributor] = []
    private var quickOpenContributors: [any SuperEditorQuickOpenContributor] = []
    private var interactionContributors: [any SuperEditorInteractionContributor] = []
    private var sheetContributors: [any SuperEditorSheetContributor] = []
    private var toolbarContributors: [any SuperEditorToolbarContributor] = []
    private var themeContributors: [any SuperEditorThemeContributor] = []
    private var projectContextCapabilities: [any SuperEditorProjectContextCapability] = []
    private var languageIntegrationCapabilities: [any SuperEditorLanguageIntegrationCapability] = []
    private var semanticCapabilities: [any SuperEditorSemanticCapability] = []
    private var _editorLSPClient: (any SuperEditorLSPClient)?
    private var _signatureHelpProvider: (any SuperEditorSignatureHelpProvider)?
    private var _inlayHintProvider: (any SuperEditorInlayHintProvider)?
    private var _documentHighlightProvider: (any SuperEditorDocumentHighlightProvider)?
    private var _codeActionProvider: (any SuperEditorCodeActionProvider)?
    private var _workspaceSymbolProvider: (any SuperEditorWorkspaceSymbolProvider)?
    private var _callHierarchyProvider: (any SuperEditorCallHierarchyProvider)?
    private var _foldingRangeProvider: (any SuperEditorFoldingRangeProvider)?
    private var _documentSymbolProvider: (any SuperEditorDocumentSymbolProvider)?
    private var _semanticTokenProvider: (any SuperEditorSemanticTokenProvider)?
    private var _diagnosticsProvider: (any SuperEditorLSPDiagnosticsProvider)?
    private var railOutlineProvidersByLanguageID: [String: EditorRailOutlineRegistration] = [:]

    /// 当前已注册的 commandContributors 数量（用于调试日志）
    public var commandContributorsCount: Int { commandContributors.count }

    public init() {}

    public func reset() {
        installedPlugins.removeAll()
        completionContributors.removeAll()
        hoverContributors.removeAll()
        hoverContentContributors.removeAll()
        codeActionContributors.removeAll()
        highlightProviderContributors.removeAll()
        cachedHighlightProvidersByLanguageID.removeAll()
        commandContributors.removeAll()
        contextMenuContributors.removeAll()
        gutterDecorationContributors.removeAll()
        panelContributors.removeAll()
        settingsContributors.removeAll()
        statusItemContributors.removeAll()
        quickOpenContributors.removeAll()
        interactionContributors.removeAll()
        sheetContributors.removeAll()
        toolbarContributors.removeAll()
        themeContributors.removeAll()
        projectContextCapabilities.removeAll()
        languageIntegrationCapabilities.removeAll()
        semanticCapabilities.removeAll()
        _editorLSPClient = nil
        _signatureHelpProvider = nil
        _inlayHintProvider = nil
        _documentHighlightProvider = nil
        _codeActionProvider = nil
        _workspaceSymbolProvider = nil
        _callHierarchyProvider = nil
        _foldingRangeProvider = nil
        _documentSymbolProvider = nil
        _semanticTokenProvider = nil
        _diagnosticsProvider = nil
        railOutlineProvidersByLanguageID.removeAll()
        LanguageRegistry.shared.reset()
        LanguageQueryRegistry.shared.reset()
    }

    // MARK: - Language Registration

    public func registerLanguage(_ descriptor: EditorLanguageDescriptor) {
        LanguageRegistry.shared.register(descriptor)
    }

    public func registerGrammarProvider(_ provider: any SuperEditorLanguageGrammarProvider) {
        LanguageRegistry.shared.registerGrammarProvider(provider)
    }

    public var languageRegistry: LanguageRegistry { .shared }

    public func registerRailOutlineProvider(
        languageId: String,
        tabID: String,
        title: String,
        systemImage: String,
        makeView: @escaping @MainActor () -> AnyView
    ) {
        railOutlineProvidersByLanguageID[languageId] = EditorRailOutlineRegistration(
            tabID: tabID,
            title: title,
            systemImage: systemImage,
            makeView: makeView
        )
    }

    public func railOutlineRegistration(for languageId: String) -> EditorRailOutlineRegistration? {
        railOutlineProvidersByLanguageID[languageId]
    }

    public func registerCompletionContributor(_ contributor: any SuperEditorCompletionContributor) {
        if completionContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        completionContributors.append(contributor)
    }

    public func registerHoverContributor(_ contributor: any SuperEditorHoverContributor) {
        if hoverContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        hoverContributors.append(contributor)
    }

    public func registerHoverContentContributor(_ contributor: any SuperEditorHoverContentContributor) {
        if hoverContentContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        hoverContentContributors.append(contributor)
    }

    public func registerCodeActionContributor(_ contributor: any SuperEditorCodeActionContributor) {
        if codeActionContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        codeActionContributors.append(contributor)
    }

    public func registerHighlightProviderContributor(_ contributor: any SuperEditorHighlightProviderContributor) {
        if highlightProviderContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        highlightProviderContributors.append(contributor)
        cachedHighlightProvidersByLanguageID.removeAll()
    }

    public func registerCommandContributor(_ contributor: any SuperEditorCommandContributor) {
        if commandContributors.contains(where: { $0.id == contributor.id }) {
            if Self.verbose {
                            Self.logger.info("\(self.t)registerCommandContributor: 已存在，跳过 id=\(contributor.id), count=\(self.commandContributors.count)")
            }
            return
        }
        commandContributors.append(contributor)
        if Self.verbose {
                    Self.logger.info("\(self.t)registerCommandContributor: id=\(contributor.id), count=\(self.commandContributors.count)")
        }
    }

    public func registerContextMenuContributor(_ contributor: any SuperEditorContextMenuContributor) {
        if contextMenuContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        contextMenuContributors.append(contributor)
    }

    public func registerGutterDecorationContributor(_ contributor: any SuperEditorGutterDecorationContributor) {
        if gutterDecorationContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        gutterDecorationContributors.append(contributor)
    }

    public func registerDecorationContributor(_ contributor: any SuperEditorDecorationContributor) {
        registerGutterDecorationContributor(contributor)
    }

    public func registerPanelContributor(_ contributor: any SuperEditorPanelContributor) {
        if panelContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        panelContributors.append(contributor)
    }

    public func registerSettingsContributor(_ contributor: any SuperEditorSettingsContributor) {
        if settingsContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        settingsContributors.append(contributor)
    }

    public func registerStatusItemContributor(_ contributor: any SuperEditorStatusItemContributor) {
        if statusItemContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        statusItemContributors.append(contributor)
    }

    public func registerQuickOpenContributor(_ contributor: any SuperEditorQuickOpenContributor) {
        if quickOpenContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        quickOpenContributors.append(contributor)
    }

    public func registerInteractionContributor(_ contributor: any SuperEditorInteractionContributor) {
        if interactionContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        interactionContributors.append(contributor)
    }

    public func registerSheetContributor(_ contributor: any SuperEditorSheetContributor) {
        if sheetContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        sheetContributors.append(contributor)
    }

    public func registerToolbarContributor(_ contributor: any SuperEditorToolbarContributor) {
        if toolbarContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        toolbarContributors.append(contributor)
    }

    // MARK: - Editor Capabilities (内核内部能力聚合)

    public func registerProjectContextCapability(_ capability: any SuperEditorProjectContextCapability) {
        if projectContextCapabilities.contains(where: { $0.id == capability.id }) {
            return
        }
        projectContextCapabilities.append(capability)
    }

    public func registerLanguageIntegrationCapability(_ capability: any SuperEditorLanguageIntegrationCapability) {
        if languageIntegrationCapabilities.contains(where: { $0.id == capability.id }) {
            return
        }
        languageIntegrationCapabilities.append(capability)
    }

    public func registerSemanticCapability(_ capability: any SuperEditorSemanticCapability) {
        if semanticCapabilities.contains(where: { $0.id == capability.id }) {
            return
        }
        semanticCapabilities.append(capability)
    }

    /// 按项目路径查找最匹配的项目上下文能力
    public func projectContextCapability(for projectPath: String?) -> (any SuperEditorProjectContextCapability)? {
        bestMatch(in: projectContextCapabilities.filter { $0.canHandleProject(at: projectPath) })
    }

    /// 关闭所有已注册的项目上下文（切换项目时确保 Xcode bridge 等单例状态被清理）
    public func closeAllProjectContexts() {
        for capability in projectContextCapabilities {
            capability.projectClosed()
        }
    }

    /// 按语言和项目路径查找最匹配的语言集成能力
    public func languageIntegrationCapability(
        for languageId: String,
        projectPath: String?
    ) -> (any SuperEditorLanguageIntegrationCapability)? {
        bestMatch(
            in: languageIntegrationCapabilities.filter { $0.supports(languageId: languageId, projectPath: projectPath) }
        )
    }

    /// 按 URI 查找最匹配的语义可用性能力
    public func semanticCapability(for uri: String?) -> (any SuperEditorSemanticCapability)? {
        bestMatch(in: semanticCapabilities.filter { $0.canHandle(uri: uri) })
    }

    // MARK: - LSP Client Registration

    /// 注册编辑器 LSP 客户端
    public func registerSuperEditorLSPClient(_ client: any SuperEditorLSPClient) {
        _editorLSPClient = client
    }

    /// 获取编辑器 LSP 客户端
    public var editorLSPClient: (any SuperEditorLSPClient)? { _editorLSPClient }

    // MARK: - LSP Provider Registration

    /// 注册签名帮助提供者
    public func registerSignatureHelpProvider(_ provider: any SuperEditorSignatureHelpProvider) {
        _signatureHelpProvider = provider
    }

    /// 注册内联提示提供者
    public func registerInlayHintProvider(_ provider: any SuperEditorInlayHintProvider) {
        _inlayHintProvider = provider
    }

    /// 注册文档高亮提供者
    public func registerDocumentHighlightProvider(_ provider: any SuperEditorDocumentHighlightProvider) {
        _documentHighlightProvider = provider
    }

    /// 注册代码动作提供者
    public func registerCodeActionProvider(_ provider: any SuperEditorCodeActionProvider) {
        _codeActionProvider = provider
    }

    /// 注册工作区符号搜索提供者
    public func registerWorkspaceSymbolProvider(_ provider: any SuperEditorWorkspaceSymbolProvider) {
        _workspaceSymbolProvider = provider
    }

    /// 注册调用层级提供者
    public func registerCallHierarchyProvider(_ provider: any SuperEditorCallHierarchyProvider) {
        _callHierarchyProvider = provider
    }

    /// 注册折叠范围提供者
    public func registerFoldingRangeProvider(_ provider: any SuperEditorFoldingRangeProvider) {
        _foldingRangeProvider = provider
    }

    /// 注册文档符号提供者
    public func registerDocumentSymbolProvider(_ provider: any SuperEditorDocumentSymbolProvider) {
        _documentSymbolProvider = provider
    }

    /// 注册语义 Token 提供者
    public func registerSemanticTokenProvider(_ provider: any SuperEditorSemanticTokenProvider) {
        _semanticTokenProvider = provider
    }

    /// 注册诊断数据流提供者
    public func registerDiagnosticsProvider(_ provider: any SuperEditorLSPDiagnosticsProvider) {
        _diagnosticsProvider = provider
    }

    // MARK: - LSP Provider Queries

    /// 获取签名帮助提供者
    public var signatureHelpProvider: (any SuperEditorSignatureHelpProvider)? { _signatureHelpProvider }

    /// 获取内联提示提供者
    public var inlayHintProvider: (any SuperEditorInlayHintProvider)? { _inlayHintProvider }

    /// 获取文档高亮提供者
    public var documentHighlightProvider: (any SuperEditorDocumentHighlightProvider)? { _documentHighlightProvider }

    /// 获取代码动作提供者
    public var codeActionProvider: (any SuperEditorCodeActionProvider)? { _codeActionProvider }

    /// 获取工作区符号搜索提供者
    public var workspaceSymbolProvider: (any SuperEditorWorkspaceSymbolProvider)? { _workspaceSymbolProvider }

    /// 获取调用层级提供者
    public var callHierarchyProvider: (any SuperEditorCallHierarchyProvider)? { _callHierarchyProvider }

    /// 获取折叠范围提供者
    public var foldingRangeProvider: (any SuperEditorFoldingRangeProvider)? { _foldingRangeProvider }

    /// 获取文档符号提供者
    public var documentSymbolProvider: (any SuperEditorDocumentSymbolProvider)? { _documentSymbolProvider }

    /// 获取语义 Token 提供者
    public var semanticTokenProvider: (any SuperEditorSemanticTokenProvider)? { _semanticTokenProvider }

    /// 获取诊断数据流提供者
    public var diagnosticsProvider: (any SuperEditorLSPDiagnosticsProvider)? { _diagnosticsProvider }

    /// 获取全部 LSP Provider 集合
    public func lspProviderSet() -> EditorLSPProviderSet {
        EditorLSPProviderSet(
            signatureHelpProvider: _signatureHelpProvider,
            inlayHintProvider: _inlayHintProvider,
            documentHighlightProvider: _documentHighlightProvider,
            codeActionProvider: _codeActionProvider,
            workspaceSymbolProvider: _workspaceSymbolProvider,
            callHierarchyProvider: _callHierarchyProvider,
            foldingRangeProvider: _foldingRangeProvider,
            documentSymbolProvider: _documentSymbolProvider,
            semanticTokenProvider: _semanticTokenProvider,
            diagnosticsProvider: _diagnosticsProvider
        )
    }

    // MARK: - Theme

    public func registerThemeContributor(_ contributor: any SuperEditorThemeContributor) {
        if themeContributors.contains(where: { $0.id == contributor.id }) {
            return
        }
        themeContributors.append(contributor)
        themeContributors.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// 注册或替换同 ID 的主题 contributor（App 主题同步时使用）。
    public func registerOrReplaceThemeContributor(_ contributor: any SuperEditorThemeContributor) {
        if let index = themeContributors.firstIndex(where: { $0.id == contributor.id }) {
            themeContributors[index] = contributor
        } else {
            themeContributors.append(contributor)
        }
        themeContributors.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// 所有已注册的主题（按 displayName 排序）
    public func allThemes() -> [any SuperEditorThemeContributor] {
        themeContributors
    }

    /// 按 ID 查找主题
    public func theme(for id: String) -> (any SuperEditorThemeContributor)? {
        themeContributors.first { $0.id == id }
    }

    public func completionSuggestions(for context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard !completionContributors.isEmpty else { return [] }
        var merged: [EditorCompletionSuggestion] = []
        for contributor in completionContributors {
            let items = await contributor.provideSuggestions(context: context)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateSuggestions(merged)
    }

    public func hoverSuggestions(for context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        guard !hoverContributors.isEmpty || !hoverContentContributors.isEmpty else { return [] }
        var merged: [EditorHoverSuggestion] = []
        for contributor in hoverContributors {
            let items = await contributor.provideHover(context: context)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        for contributor in hoverContentContributors {
            let items = await contributor.provideHoverContent(context: context)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateHovers(merged)
    }

    public func codeActionSuggestions(for context: EditorCodeActionContext) async -> [EditorCodeActionSuggestion] {
        guard !codeActionContributors.isEmpty else { return [] }
        var merged: [EditorCodeActionSuggestion] = []
        for contributor in codeActionContributors {
            let items = await contributor.provideCodeActions(context: context)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateCodeActions(merged)
    }

    public func commandSuggestions(
        for context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        guard !commandContributors.isEmpty else {
            if Self.verbose { Self.logger.warning("\(self.t)commandSuggestions: commandContributors 为空") }
            return []
        }
        if Self.verbose { Self.logger.info("\(self.t)commandSuggestions: contributors.count=\(self.commandContributors.count), ids=\(self.commandContributors.map(\.id))") }
        var merged: [EditorCommandSuggestion] = []
        for contributor in commandContributors {
            let items = contributor.provideCommands(
                context: context,
                state: state,
                textView: textView
            )
            if Self.verbose { Self.logger.info("\(self.t)commandSuggestions: contributor=\(contributor.id) 返回 \(items.count) 个命令") }
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        let result = deduplicateCommands(merged)
        if Self.verbose { Self.logger.info("\(self.t)commandSuggestions: 去重后共 \(result.count) 个命令") }
        return result
    }

    public func contextMenuSuggestions(
        for context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorContextMenuItemSuggestion] {
        let contributionContext = makeContributionContext(
            state: state,
            legacyContext: context
        )

        let commandsBeforeFilter = commandSuggestions(
            for: context,
            state: state,
            textView: textView
        ).map(EditorContextMenuItemSuggestion.init(command:))

        if Self.verbose { Self.logger.info("\(self.t)contextMenuSuggestions: commandSuggestions 返回 \(commandsBeforeFilter.count) 项, contextMenuContributors.count=\(self.contextMenuContributors.count)") }

        var merged = commandsBeforeFilter

        for contributor in contextMenuContributors {
            let items = contributor.provideContextMenuItems(
                context: context,
                state: state,
                textView: textView
            )
            if Self.verbose { Self.logger.info("\(self.t)contextMenuSuggestions: contributor=\(contributor.id) 返回 \(items.count) 项") }
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }

        let beforeFilter = merged.count
        let filtered = merged.filter { $0.isEnabled && $0.metadata.matches(contributionContext) }
        if Self.verbose { Self.logger.info("\(self.t)contextMenuSuggestions: 合并后 \(beforeFilter) 项, 过滤后 \(filtered.count) 项") }

        if beforeFilter > 0 && filtered.isEmpty {
            if Self.verbose {
                if Self.verbose {
                                    Self.logger.warning("\(self.t)contextMenuSuggestions: 所有命令被过滤掉了")
                }
                for item in merged.prefix(5) {
                    if Self.verbose {
                                            Self.logger.warning("\(self.t)contextMenuSuggestions: 被过滤的命令: id=\(item.id), isEnabled=\(item.isEnabled), whenClause=\(item.metadata.whenClause != nil)")
                    }
                }
            }
        }

        let result = deduplicateContextMenuSuggestions(filtered)
        if Self.verbose { Self.logger.info("\(self.t)contextMenuSuggestions: 去重后返回 \(result.count) 项") }
        return result
    }

    public func gutterDecorationSuggestions(
        for context: EditorGutterDecorationContext,
        state: EditorState
    ) -> [EditorGutterDecorationSuggestion] {
        guard !gutterDecorationContributors.isEmpty else { return [] }
        var merged: [EditorGutterDecorationSuggestion] = []
        for contributor in gutterDecorationContributors {
            let items = contributor.provideGutterDecorations(context: context, state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateGutterDecorations(merged)
    }

    public func sheetSuggestions(state: EditorState) -> [EditorSheetSuggestion] {
        var merged: [EditorSheetSuggestion] = []
        for panel in panelSuggestions(state: state) where panel.placement == .sheet {
            merged.append(
                EditorSheetSuggestion(
                    id: panel.id,
                    order: panel.order,
                    isPresented: panel.isPresented,
                    onDismiss: panel.onDismiss,
                    content: panel.content
                )
            )
        }
        for contributor in sheetContributors {
            let items = contributor.provideSheets(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateSheets(merged)
    }

    public func panelSuggestions(state: EditorState) -> [EditorPanelSuggestion] {
        guard !panelContributors.isEmpty else { return [] }
        let contributionContext = makeContributionContext(state: state)
        var merged: [EditorPanelSuggestion] = []
        for contributor in panelContributors {
            let items = contributor.providePanels(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicatePanels(
            merged.filter { $0.metadata.matches(contributionContext) }
        )
    }

    public func settingsSuggestions(state: EditorSettingsState) -> [EditorSettingsItemSuggestion] {
        guard !settingsContributors.isEmpty else { return [] }
        let contributionContext = makeContributionContext(state: state)
        var merged: [EditorSettingsItemSuggestion] = []
        for contributor in settingsContributors {
            let items = contributor.provideSettingsItems(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateSettingsItems(
            merged.filter { $0.metadata.matches(contributionContext) }
        )
    }

    public func toolbarItemSuggestions(state: EditorState) -> [EditorToolbarItemSuggestion] {
        var merged: [EditorToolbarItemSuggestion] = []
        for item in statusItemSuggestions(state: state)
        where item.placement == .toolbarCenter || item.placement == .toolbarTrailing {
            merged.append(EditorToolbarItemSuggestion(statusItem: item))
        }
        for contributor in toolbarContributors {
            let items = contributor.provideToolbarItems(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateToolbarItems(merged)
    }

    public func statusItemSuggestions(state: EditorState) -> [EditorStatusItemSuggestion] {
        guard !statusItemContributors.isEmpty else { return [] }
        let contributionContext = makeContributionContext(state: state)
        var merged: [EditorStatusItemSuggestion] = []
        for contributor in statusItemContributors {
            let items = contributor.provideStatusItems(state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateStatusItems(
            merged.filter { $0.metadata.matches(contributionContext) }
        )
    }

    public func quickOpenSuggestions(
        matching query: String,
        state: EditorState
    ) async -> [EditorQuickOpenItemSuggestion] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, !quickOpenContributors.isEmpty else { return [] }
        let contributionContext = makeContributionContext(state: state)

        var merged: [EditorQuickOpenItemSuggestion] = []
        for contributor in quickOpenContributors {
            let items = await contributor.provideQuickOpenItems(query: trimmedQuery, state: state)
            if !items.isEmpty {
                merged.append(contentsOf: items)
            }
        }
        return deduplicateQuickOpenItems(
            merged.filter { $0.isEnabled && $0.metadata.matches(contributionContext) }
        )
    }

    private func makeContributionContext(
        state: EditorState,
        legacyContext: EditorCommandContext? = nil
    ) -> EditorContributionContext {
        EditorContributionContext(
            languageId: legacyContext?.languageId ?? state.detectedLanguage?.tsName ?? "swift",
            fileURL: state.currentFileURL,
            hasSelection: legacyContext?.hasSelection ?? false,
            line: legacyContext?.line ?? max(state.cursorLine - 1, 0),
            character: legacyContext?.character ?? max(state.cursorColumn - 1, 0),
            isEditorActive: state.currentFileURL != nil,
            isLargeFileMode: state.largeFileMode != .normal
        )
    }

    private func makeContributionContext(state: EditorSettingsState) -> EditorContributionContext {
        EditorContributionContext(
            languageId: "settings",
            fileURL: nil,
            hasSelection: false,
            line: 0,
            character: 0,
            isEditorActive: false,
            isLargeFileMode: false
        )
    }

    public func highlightProviders(for languageId: String) -> [any HighlightProviding] {
        if let cached = cachedHighlightProvidersByLanguageID[languageId] {
            return cached
        }
        guard !highlightProviderContributors.isEmpty else { return [] }

        let contributors = highlightProviderContributors
        var merged: [any HighlightProviding] = []
        var seenContributorIDs: Set<ObjectIdentifier> = []

        for contributor in contributors where contributor.supports(languageId: languageId) {
            // 在 contributor 级别去重，避免对 any HighlightProviding existential
            // 调用 ObjectIdentifier 导致 swift_getObjectType 空指针崩溃
            let contributorID = ObjectIdentifier(contributor)
            guard seenContributorIDs.insert(contributorID).inserted else { continue }
            merged.append(contentsOf: contributor.provideHighlightProviders(languageId: languageId))
        }

        cachedHighlightProvidersByLanguageID[languageId] = merged
        return merged
    }

    public func runInteractionTextDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async {
        guard !interactionContributors.isEmpty else { return }
        for contributor in interactionContributors {
            await contributor.onTextDidChange(
                context: context,
                state: state,
                controller: controller
            )
        }
    }

    public func runInteractionSelectionDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async {
        guard !interactionContributors.isEmpty else { return }
        for contributor in interactionContributors {
            await contributor.onSelectionDidChange(
                context: context,
                state: state,
                controller: controller
            )
        }
    }

    private func deduplicateSuggestions(_ suggestions: [EditorCompletionSuggestion]) -> [EditorCompletionSuggestion] {
        var seen: Set<String> = []
        var result: [EditorCompletionSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }

        for item in sorted {
            let key = item.label.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateHovers(_ suggestions: [EditorHoverSuggestion]) -> [EditorHoverSuggestion] {
        var seen: Set<String> = []
        var result: [EditorHoverSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            lhs.priority > rhs.priority
        }

        for item in sorted {
            let key = (item.dedupeKey ?? item.markdown).trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateCodeActions(_ suggestions: [EditorCodeActionSuggestion]) -> [EditorCodeActionSuggestion] {
        var seen: Set<String> = []
        var result: [EditorCodeActionSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        for item in sorted {
            let key = item.id.lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateCommands(_ suggestions: [EditorCommandSuggestion]) -> [EditorCommandSuggestion] {
        var seen: Set<String> = []
        var result: [EditorCommandSuggestion] = []
        let sorted = suggestions.sortedForCommandPresentation()

        for item in sorted {
            let key = item.id.lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateContextMenuSuggestions(_ suggestions: [EditorContextMenuItemSuggestion]) -> [EditorContextMenuItemSuggestion] {
        var seen: Set<String> = []
        var result: [EditorContextMenuItemSuggestion] = []
        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.metadata.priority != rhs.metadata.priority {
                return lhs.metadata.priority > rhs.metadata.priority
            }
            let lhsCommand = lhs.asCommandSuggestion
            let rhsCommand = rhs.asCommandSuggestion
            if lhsCommand.order != rhsCommand.order {
                return lhsCommand.order < rhsCommand.order
            }
            return lhsCommand.title.localizedCaseInsensitiveCompare(rhsCommand.title) == .orderedAscending
        }

        for item in sorted {
            let key = (item.metadata.dedupeKey ?? item.id).lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateGutterDecorations(_ suggestions: [EditorGutterDecorationSuggestion]) -> [EditorGutterDecorationSuggestion] {
        var seen: Set<String> = []
        var result: [EditorGutterDecorationSuggestion] = []
        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.line != rhs.line { return lhs.line < rhs.line }
            if lhs.lane != rhs.lane { return lhs.lane < rhs.lane }
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        for item in sorted {
            let key = "\(item.line):\(item.lane):\(item.id.lowercased())"
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicatePanels(_ suggestions: [EditorPanelSuggestion]) -> [EditorPanelSuggestion] {
        var seen: Set<String> = []
        var result: [EditorPanelSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.placement != rhs.placement {
                return lhs.placement.rawValue.localizedCaseInsensitiveCompare(rhs.placement.rawValue) == .orderedAscending
            }
            if lhs.metadata.priority != rhs.metadata.priority {
                return lhs.metadata.priority > rhs.metadata.priority
            }
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        for item in sorted {
            let key = "\(item.placement.rawValue):\((item.metadata.dedupeKey ?? item.id).lowercased())"
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateSheets(_ suggestions: [EditorSheetSuggestion]) -> [EditorSheetSuggestion] {
        var seen: Set<String> = []
        var result: [EditorSheetSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        for item in sorted {
            let key = item.id.lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateToolbarItems(_ suggestions: [EditorToolbarItemSuggestion]) -> [EditorToolbarItemSuggestion] {
        var seen: Set<String> = []
        var result: [EditorToolbarItemSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        for item in sorted {
            let key = item.id.lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateSettingsItems(_ suggestions: [EditorSettingsItemSuggestion]) -> [EditorSettingsItemSuggestion] {
        var seen: Set<String> = []
        var result: [EditorSettingsItemSuggestion] = []
        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.metadata.priority != rhs.metadata.priority {
                return lhs.metadata.priority > rhs.metadata.priority
            }
            if lhs.sectionTitle != rhs.sectionTitle {
                return lhs.sectionTitle.localizedCaseInsensitiveCompare(rhs.sectionTitle) == .orderedAscending
            }
            if lhs.order != rhs.order {
                return lhs.order < rhs.order
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        for item in sorted {
            let key = (item.metadata.dedupeKey ?? item.id).lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateStatusItems(_ suggestions: [EditorStatusItemSuggestion]) -> [EditorStatusItemSuggestion] {
        var seen: Set<String> = []
        var result: [EditorStatusItemSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.placement != rhs.placement {
                return lhs.placement.rawValue.localizedCaseInsensitiveCompare(rhs.placement.rawValue) == .orderedAscending
            }
            if lhs.metadata.priority != rhs.metadata.priority {
                return lhs.metadata.priority > rhs.metadata.priority
            }
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
        }

        for item in sorted {
            let key = "\(item.placement.rawValue):\((item.metadata.dedupeKey ?? item.id).lowercased())"
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func deduplicateQuickOpenItems(_ suggestions: [EditorQuickOpenItemSuggestion]) -> [EditorQuickOpenItemSuggestion] {
        var seen: Set<String> = []
        var result: [EditorQuickOpenItemSuggestion] = []

        let sorted = suggestions.sorted { lhs, rhs in
            if lhs.sectionTitle != rhs.sectionTitle {
                return lhs.sectionTitle.localizedCaseInsensitiveCompare(rhs.sectionTitle) == .orderedAscending
            }
            if lhs.metadata.priority != rhs.metadata.priority {
                return lhs.metadata.priority > rhs.metadata.priority
            }
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        for item in sorted {
            let key = (item.metadata.dedupeKey ?? item.id).lowercased()
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private func bestMatch(
        in providers: [any SuperEditorProjectContextCapability]
    ) -> (any SuperEditorProjectContextCapability)? {
        providers.sorted {
            if $0.priority != $1.priority {
                return $0.priority > $1.priority
            }
            return $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
        }.first
    }

    private func bestMatch(
        in providers: [any SuperEditorLanguageIntegrationCapability]
    ) -> (any SuperEditorLanguageIntegrationCapability)? {
        providers.sorted {
            if $0.priority != $1.priority {
                return $0.priority > $1.priority
            }
            return $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
        }.first
    }

    private func bestMatch(
        in providers: [any SuperEditorSemanticCapability]
    ) -> (any SuperEditorSemanticCapability)? {
        providers.sorted {
            if $0.priority != $1.priority {
                return $0.priority > $1.priority
            }
            return $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
        }.first
    }
}
