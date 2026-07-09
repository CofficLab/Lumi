import SwiftUI
import SuperLogKit
import EditorService
import LSPDocumentHighlightEditorPlugin
import LSPRealtimeSignalsPlugin
import LSPSignatureHelpEditorPlugin
import LumiCoreKit
import LumiUI

/// 代码编辑器主视图。
/// 基于 EditorSource 实现专业级编辑体验。
///
/// 该视图负责装配编辑器实例、状态协调器以及各类 overlay 子视图，是
/// EditorPanel 中源码编辑体验的核心入口。
public struct SourceEditorView: View, SuperLog {
    public nonisolated static let emoji = "📝"
    public nonisolated static let verbose: Bool = true
    
    @ObservedObject var state: EditorState
    @EnvironmentObject private var themeVM: AppThemeVM
    @ObservedObject private var themeRegistry = LumiUIThemeRegistry.shared
    @Environment(\.colorScheme) private var colorScheme
    private let adapter = SourceEditorAdapter()
    private let bridge = SourceEditorViewBridge()
    
    /// 编辑器协调器（使用 @State 确保在 View 更新间保持同一实例）
    @State private var textCoordinator: EditorCoordinator?
    @State private var cursorCoordinator: CursorCoordinator?
    @State private var scrollCoordinator: ScrollCoordinator?
    @State private var contextMenuCoordinator: ContextMenuCoordinator?
    @State private var semanticTokenProvider: (any SuperEditorSemanticTokenProvider)?
    @State private var semanticTokenHighlightProvider: (any HighlightProviding)?
    @State private var documentHighlightProvider: DocumentHighlightHighlightAdapter?
    @State private var hoverCoordinator: HoverEditorCoordinator?
    
    /// 跳转到定义代理（Cmd+Click / 右键跳转共用同一实例）
    @StateObject private var jumpDelegate: EditorJumpToDefinitionDelegate = {
        let d = EditorJumpToDefinitionDelegate()
        return d
    }()
    @State private var completionDelegate = LSPCompletionDelegate()
    
    /// tree-sitter 客户端
    @State private var treeSitterClient = TreeSitterClient()
    
    /// 缓存的配置
    @State private var cachedConfig: SourceEditorConfiguration?
    @State private var contentLineTable: LineOffsetTable?
    
    /// 缓存的 hover 卡片尺寸，用于统一定位策略
    @State private var hoverPopoverSize: CGSize = CGSize(width: 320, height: 100)
    
    public init(state: EditorState) {
        self._state = ObservedObject(wrappedValue: state)
    }
    
    public var body: some View {
        let base = AnyView(editorContent
            .onAppear {
                initializeCoordinators()
                wireDelegates()
                updateContentLineTable()
                state.refreshFoldingRanges()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: EditorHostEnvironment.current.notifications.editorExtensionProvidersDidChange
                )
            ) { _ in
                wireDelegates()
            })

        let appearanceObserved = AnyView(base
            .onChange(of: state.fontSize) { _, _ in updateConfigCache() }
            .onChange(of: state.fontName) { _, _ in updateConfigCache() }
            .onChange(of: state.wrapLines) { _, _ in updateConfigCache() }
            .onChange(of: state.showGutter) { _, _ in updateConfigCache() }
            .onChange(of: state.showMinimap) { _, _ in updateConfigCache() }
            .onChange(of: state.showFoldingRibbon) { _, _ in updateConfigCache() }
            .onChange(of: state.tabWidth) { _, _ in updateConfigCache() }
            .onChange(of: state.useSpaces) { _, _ in updateConfigCache() }
            .onChange(of: state.currentTheme) { _, _ in updateConfigCache() }
            .onChange(of: themeVM.activeChromeTheme.identifier) { _, _ in updateConfigCache() }
            .onChange(of: themeRegistry.systemColorScheme) { _, _ in updateConfigCache() }
            .onChange(of: colorScheme) { _, _ in updateConfigCache() }
            .onChange(of: state.largeFileMode) { _, _ in updateConfigCache() })

        let runtimeObserved = AnyView(appearanceObserved
            .onChange(of: state.isSyntaxHighlightingEnabledInViewport) { _, isEnabled in
                semanticTokenProvider?.setEnabled(isEnabled)
            }
            .onChange(of: state.viewportRenderLineRange) { _, _ in
                if state.shouldCancelHoverForViewportTransition {
                    hoverCoordinator?.cancelHover()
                }
                state.handleViewportRuntimeTransition()
            }
            .onChange(of: state.areDocumentHighlightsEnabled) { _, isEnabled in
                state.handleDocumentHighlightRuntimeAvailabilityChange(isEnabled)
            }
            .onChange(of: state.areHoversEnabled) { _, isEnabled in
                if state.shouldCancelHoverForRuntimeAvailabilityChange(isEnabled) {
                    hoverCoordinator?.cancelHover()
                }
            }
            .onChange(of: state.areSignatureHelpEnabled) { _, isEnabled in
                state.handleSignatureHelpRuntimeAvailabilityChange(isEnabled)
            }
            .onChange(of: state.areCodeActionsEnabled) { _, isEnabled in
                state.handleCodeActionRuntimeAvailabilityChange(isEnabled)
            })

        return AnyView(runtimeObserved
            .onChange(of: state.content) { _, newContent in
                jumpDelegate.textStorage = newContent
                updateContentLineTable()
                state.refreshFoldingRanges()
            }
            .onChange(of: state.currentCodeActionOverlayActions.map(\.id)) { _, ids in
                if ids.isEmpty {
                    state.dismissCodeActionPanel()
                } else {
                    state.reconcileCodeActionPanelState(preferPreferred: state.isCodeActionPanelPresented)
                }
            }
            .onChange(of: state.currentFileURL) { _, _ in
                updateConfigCache()
                state.dismissCodeActionPanel()
                state.dismissPeek()
                state.dismissInlineRename()
                state.refreshFoldingRanges()
            }
            .contentShape(Rectangle())
            .clipped())
    }

    // MARK: - Editor Content

    /// 编辑器主体内容
    @ViewBuilder
    private var editorContent: some View {
        if let content = state.content,
           textCoordinator != nil,
           cursorCoordinator != nil,
           contextMenuCoordinator != nil {
            let config = cachedConfig ?? buildConfiguration()
            VStack(spacing: 0) {
                SourceEditor(
                    content,
                    language: resolvedLanguage,
                    configuration: config,
                    state: sourceEditorBinding,
                    highlightProviders: activeHighlightProviders,
                    coordinators: activeCoordinators,
                    completionDelegate: completionDelegate,
                    jumpToDefinitionDelegate: jumpDelegate
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                inlayHintsStrip
            }
//            .overlay(alignment: .topLeading) {
//                EditorGutterDecorationsOverlayView(
//                    decorations: visibleGutterDecorations,
//                    openDiagnostic: state.openProblem(atLine:)
//                )
//            }
//            .overlay(alignment: .topLeading) {
//                EditorSurfaceHighlightsOverlayView(highlights: visibleSurfaceHighlights)
//            }
//            .overlay(alignment: .topLeading) {
//                EditorSecondaryCursorOverlayView(highlights: visibleSecondaryCursorHighlights)
//            }
//            .overlay(alignment: .topLeading) {
//                GeometryReader { proxy in
//                    EditorInlinePresentationsOverlayView(
//                        presentations: inlinePresentations(in: proxy.size)
//                    )
//                }
//            }
//            .overlay(alignment: .topLeading) {
//                GeometryReader { proxy in
//                    EditorHoverOverlayView(
//                        state: state,
//                        containerSize: proxy.size,
//                        hoverPopoverSize: $hoverPopoverSize
//                    )
//                }
//            }
//            .overlay(alignment: .bottomTrailing) {
//                peekOverlay
//            }
//            .overlay(alignment: .top) {
//                inlineRenameOverlay
//            }
//            .overlay(alignment: .bottomLeading) {
//                signatureHelpOverlay
//            }
//            .overlay(alignment: .topLeading) {
//                codeActionOverlay
//            }
        } else {
            EditorEmptyContentStateView()
        }
    }
    
    // MARK: - Overlays

    @ViewBuilder
    private var peekOverlay: some View {
        if let presentation = state.currentPeekPresentation {
            EditorPeekOverlayView(state: state, presentation: presentation)
                .padding(.trailing, 14)
                .padding(.bottom, 38)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                ))
                .animation(.easeOut(duration: 0.16), value: presentation)
        }
    }

    @ViewBuilder
    private var inlineRenameOverlay: some View {
        if state.currentInlineRenameState != nil {
            EditorInlineRenameOverlayView(
                state: state,
                renameState: Binding(
                    get: { state.currentInlineRenameState ?? EditorInlineRenameState(
                        originalName: "",
                        draftName: "",
                        isLoadingPreview: false,
                        errorMessage: nil,
                        previewSummary: nil,
                        previewEdit: nil
                    ) },
                    set: { state.currentInlineRenameState = $0 }
                )
            )
            .padding(.top, 14)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity
            ))
            .animation(.easeOut(duration: 0.16), value: state.currentInlineRenameState?.draftName)
        }
    }

    @ViewBuilder
    private var signatureHelpOverlay: some View {
        if let help = state.currentSignatureHelpOverlayItem {
            SignatureHelpView(item: help)
                .padding(.leading, 12)
                .padding(.bottom, 32)
        }
    }
    
    @ViewBuilder
    private var codeActionOverlay: some View {
        EditorCodeActionOverlayView(
            state: state,
            lineTable: contentLineTable
        )
    }

    @ViewBuilder
    private var inlayHintsStrip: some View {
        if state.shouldPresentInlayHintsStrip {
            let hints = state.currentRenderedInlayHints
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(hints.prefix(24)) { hint in
                        Text(LumiPluginLocalization.string("L\(hint.line + 1) \(hint.text)", bundle: .module))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 22)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "98989E").opacity(0.06))
        }
    }

    private func inlinePresentations(in containerSize: CGSize) -> [EditorInlinePresentation] {
        if let textView = state.focusedTextView,
           let lineTable = contentLineTable {
            return state.inlinePresentations(
                textView: textView,
                lineTable: lineTable,
                containerSize: containerSize
            )
        }
        return []
    }

    // MARK: - Initialization & Delegates

    /// 首次出现时初始化协调器和配置缓存
    private func initializeCoordinators() {
        let current = SourceEditorCoordinatorSet(
            textCoordinator: textCoordinator,
            cursorCoordinator: cursorCoordinator,
            scrollCoordinator: scrollCoordinator,
            contextMenuCoordinator: contextMenuCoordinator,
            semanticTokenProvider: semanticTokenProvider,
            semanticTokenHighlightProvider: semanticTokenHighlightProvider,
            documentHighlightProvider: documentHighlightProvider,
            hoverCoordinator: hoverCoordinator
        )
        let next = bridge.initializeCoordinators(state: state, current: current)
        textCoordinator = next.textCoordinator
        cursorCoordinator = next.cursorCoordinator
        scrollCoordinator = next.scrollCoordinator
        contextMenuCoordinator = next.contextMenuCoordinator
        semanticTokenProvider = next.semanticTokenProvider
        semanticTokenHighlightProvider = next.semanticTokenHighlightProvider
        documentHighlightProvider = next.documentHighlightProvider
        hoverCoordinator = next.hoverCoordinator
        if cachedConfig == nil {
            updateConfigCache()
        }
        if contentLineTable == nil {
            updateContentLineTable()
        }
    }

    private func wireDelegates() {
        bridge.wireDelegates(
            state: state,
            jumpDelegate: jumpDelegate,
            treeSitterClient: treeSitterClient,
            textCoordinator: textCoordinator,
            completionDelegate: &completionDelegate
        )
    }
    
    // MARK: - Configuration Management
    
    private func updateConfigCache() {
        cachedConfig = buildConfiguration()
    }

    private func updateContentLineTable() {
        contentLineTable = bridge.lineTable(for: state.content)
    }
    
    // MARK: - Language
    
    private var resolvedLanguage: EditorLanguageContext {
        adapter.resolvedLanguage(for: state)
    }

    private var activeHighlightProviders: [any HighlightProviding] {
        adapter.activeHighlightProviders(
            for: state,
            treeSitterClient: treeSitterClient,
            semanticTokenProvider: semanticTokenHighlightProvider,
            documentHighlightProvider: documentHighlightProvider
        )
    }
    
    private var activeCoordinators: [TextViewCoordinator] {
        adapter.activeCoordinators(
            textCoordinator: textCoordinator,
            cursorCoordinator: cursorCoordinator,
            scrollCoordinator: scrollCoordinator,
            contextMenuCoordinator: contextMenuCoordinator,
            hoverCoordinator: hoverCoordinator
        )
    }

    private var visibleSurfaceHighlights: [EditorSurfaceHighlight] {
        adapter.visibleSurfaceHighlights(
            for: state,
            textView: state.focusedTextView,
            lineTable: contentLineTable
        )
    }

    private var visibleGutterDecorations: [EditorGutterDecoration] {
        adapter.visibleGutterDecorations(
            for: state,
            textView: state.focusedTextView,
            lineTable: contentLineTable
        )
    }

    private var visibleSecondaryCursorHighlights: [EditorMultiCursorHighlight] {
        guard let textView = state.focusedTextView,
              let lineTable = contentLineTable else {
            return []
        }
        return state.secondaryCursorHighlights(textView: textView, lineTable: lineTable)
    }
    
    // MARK: - Configuration

    /// 提供给 SourceEditor 的安全 Binding。
    ///
    /// ## 解决的问题
    ///
    /// ### 1. 滚动位置反馈循环
    /// 修复：不在 get 中返回 scrollPosition，始终返回 nil。
    ///
    /// ### 2. Publishing changes from within view updates
    /// 修复：使用 DispatchQueue.main.async 延迟所有 @Published 属性修改。
    ///
    /// ### 3. 多光标模式下光标丢失
    /// 修复：多光标模式下忽略 cursorPositions 回写。
    private var sourceEditorBinding: Binding<SourceEditorState> {
        bridge.binding(for: state)
    }

    @MainActor
    private func buildConfiguration() -> SourceEditorConfiguration {
        var config = adapter.configuration(
            for: state,
            completionTriggerCharacters: completionDelegate.completionTriggerCharacters()
        )
        applyAppChromeTheme(to: &config)
        return config
    }

    /// 以 App 主题注册表为单一来源解析编辑器语法主题。
    @MainActor
    private func applyAppChromeTheme(to config: inout SourceEditorConfiguration) {
        let chromeTheme = themeVM.activeChromeTheme
        let scheme = effectiveColorScheme(for: chromeTheme)
        let resolved = EditorSyntaxThemeResolver.resolve(
            registry: LumiUIThemeRegistry.shared,
            extensions: state.editorExtensions,
            colorScheme: scheme
        )
        config.appearance.theme = resolved.theme
        config.appearance.themeIdentifier = resolved.id
    }

    private func effectiveColorScheme(for chromeTheme: any LumiAppChromeTheme) -> ColorScheme {
        if chromeTheme.followsSystemAppearance {
            return SystemAppearanceResolver.effectiveColorScheme
        }
        return colorScheme
    }
}
