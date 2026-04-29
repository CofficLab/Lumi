import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import MagicKit

/// 代码编辑器主视图
/// 基于 CodeEditSourceEditor 实现专业级编辑体验
struct SourceEditorView: View, SuperLog {
    nonisolated static let emoji = "📝"
    nonisolated static let verbose: Bool = true
    
    @ObservedObject var state: EditorState
    private let adapter = SourceEditorAdapter()
    private let bridge = SourceEditorViewBridge()
    
    /// 编辑器协调器（使用 @State 确保在 View 更新间保持同一实例）
    @State private var textCoordinator: EditorCoordinator?
    @State private var cursorCoordinator: CursorCoordinator?
    @State private var scrollCoordinator: ScrollCoordinator?
    @State private var contextMenuCoordinator: ContextMenuCoordinator?
    @State private var semanticTokenProvider: SemanticTokenHighlightProvider?
    @State private var documentHighlightProvider: DocumentHighlightHighlighter?
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
    
    /// 缓存的 popover 高度，用于在上方定位时避免遮挡
    @State private var hoverPopoverHeight: CGFloat = 100
    
    init(state: EditorState) {
        self._state = ObservedObject(wrappedValue: state)
    }
    
    var body: some View {
        configuredEditorContent
    }

    private var configuredEditorContent: some View {
        let base = editorContent
            .onAppear {
                initializeCoordinators()
                wireDelegates()
                updateContentLineTable()
            }

        let appearanceObserved = base
            .onChange(of: state.fontSize) { _, _ in updateConfigCache() }
            .onChange(of: state.wrapLines) { _, _ in updateConfigCache() }
            .onChange(of: state.showGutter) { _, _ in updateConfigCache() }
            .onChange(of: state.showMinimap) { _, _ in updateConfigCache() }
            .onChange(of: state.showFoldingRibbon) { _, _ in updateConfigCache() }
            .onChange(of: state.tabWidth) { _, _ in updateConfigCache() }
            .onChange(of: state.useSpaces) { _, _ in updateConfigCache() }
            .onChange(of: state.currentThemeId) { _, _ in updateConfigCache() }
            .onChange(of: state.currentTheme) { _, _ in updateConfigCache() }
            .onChange(of: state.largeFileMode) { _, _ in updateConfigCache() }

        let runtimeObserved = appearanceObserved
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
            }

        return runtimeObserved
            .onChange(of: state.content) { _, newContent in
                jumpDelegate.textStorage = newContent
                updateContentLineTable()
            }
            .onChange(of: state.currentFileURL) { _, _ in
                updateConfigCache()
            }
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
            .overlay(alignment: .topLeading) {
                findMatchesOverlay
            }
            .overlay(alignment: .topLeading) {
                bracketMatchOverlay
            }
            .overlay(alignment: .topLeading) {
                GeometryReader { proxy in
                    hoverPreview(in: proxy.size)
                }
            }
            .overlay(alignment: .bottomLeading) {
                signatureHelpOverlay
            }
            .overlay(alignment: .topLeading) {
                codeActionOverlay
            }
        } else {
            Text(String(localized: "No content available", table: "LumiEditor"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Overlays

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
        if state.shouldPresentCodeActionOverlay {
            CodeActionPanel(
                actions: state.currentCodeActionOverlayActions
            ) { action in
                Task { @MainActor in
                    await state.performCodeActionOverlayAction(action)
                }
            }
            .padding(.leading, 12)
            .padding(.top, 48)
        }
    }

    @ViewBuilder
    private var inlayHintsStrip: some View {
        if state.shouldPresentInlayHintsStrip {
            let hints = state.currentRenderedInlayHints
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(hints.prefix(24)) { hint in
                        Text("L\(hint.line + 1) \(hint.text)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 22)
            .frame(maxWidth: .infinity)
            .background(AppUI.Color.semantic.textTertiary.opacity(0.06))
        }
    }

    @ViewBuilder
    private var findMatchesOverlay: some View {
        let highlights = visibleFindMatchHighlights
        if !highlights.isEmpty {
            ZStack(alignment: .topLeading) {
                ForEach(highlights) { highlight in
                    RoundedRectangle(cornerRadius: highlight.isSelected ? 4 : 3)
                        .fill(highlight.color)
                        .overlay(
                            RoundedRectangle(cornerRadius: highlight.isSelected ? 4 : 3)
                                .stroke(highlight.borderColor, lineWidth: highlight.isSelected ? 1 : 0.5)
                        )
                        .frame(width: max(highlight.rect.width, 2), height: max(highlight.rect.height, 2))
                        .offset(x: highlight.rect.minX, y: highlight.rect.minY)
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var bracketMatchOverlay: some View {
        if let textView = state.focusedTextView,
           let lineTable = contentLineTable,
           let overlayRects = state.renderedBracketOverlayRects(textView: textView, lineTable: lineTable) {

            let bracketColor = AppUI.Color.semantic.primary
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(bracketColor.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(bracketColor.opacity(0.6), lineWidth: 1)
                    )
                    .frame(width: overlayRects.open.width, height: overlayRects.open.height)
                    .offset(x: overlayRects.open.minX, y: overlayRects.open.minY)

                RoundedRectangle(cornerRadius: 2)
                    .fill(bracketColor.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(bracketColor.opacity(0.6), lineWidth: 1)
                    )
                    .frame(width: overlayRects.close.width, height: overlayRects.close.height)
                    .offset(x: overlayRects.close.minX, y: overlayRects.close.minY)
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Hover Popover

    @ViewBuilder
    private func hoverPreview(in containerSize: CGSize) -> some View {
        if let hoverText = state.currentHoverOverlayText {
            HoverPopoverView(markdownText: hoverText)
                .onAppear {
                    if EditorPlugin.verbose {
                        EditorPlugin.logger.debug("\(Self.t)悬停预览: 内容长度=\(hoverText.count), 矩形=\(String(describing: state.currentHoverOverlayRect))")
                        EditorPlugin.logger.debug("\(Self.t)悬停预览: 原始内容=\n\(hoverText)")
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440, alignment: .leading)
                // 使用 GeometryReader 测量实际高度后调整位置
                .background(
                    GeometryReader { popoverGeo in
                        Color.clear
                            .onAppear {
                                hoverPopoverHeight = popoverGeo.size.height
                            }
                            .onChange(of: popoverGeo.size.height) { _, newHeight in
                                hoverPopoverHeight = newHeight
                            }
                    }
                )
                .offset(
                    state.hoverOverlayOffset(
                        in: containerSize,
                        popoverHeight: hoverPopoverHeight
                    )
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)),
                    removal: .opacity
                ))
                .animation(.easeOut(duration: 0.14), value: state.currentHoverOverlayText)
                .animation(.easeOut(duration: 0.12), value: state.currentHoverOverlayRect)
        }
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
            documentHighlightProvider: documentHighlightProvider,
            hoverCoordinator: hoverCoordinator
        )
        let next = bridge.initializeCoordinators(state: state, current: current)
        textCoordinator = next.textCoordinator
        cursorCoordinator = next.cursorCoordinator
        scrollCoordinator = next.scrollCoordinator
        contextMenuCoordinator = next.contextMenuCoordinator
        semanticTokenProvider = next.semanticTokenProvider
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
    
    private var resolvedLanguage: CodeLanguage {
        adapter.resolvedLanguage(for: state)
    }

    private var activeHighlightProviders: [any HighlightProviding] {
        adapter.activeHighlightProviders(
            for: state,
            treeSitterClient: treeSitterClient,
            semanticTokenProvider: semanticTokenProvider,
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

    private var visibleFindMatchHighlights: [SourceEditorFindMatchHighlight] {
        adapter.visibleFindMatchHighlights(
            for: state,
            textView: state.focusedTextView,
            lineTable: contentLineTable
        )
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
        adapter.configuration(
            for: state,
            completionDelegate: completionDelegate
        )
    }
}
