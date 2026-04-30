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
    
    /// 缓存的 hover 卡片尺寸，用于统一定位策略
    @State private var hoverPopoverSize: CGSize = CGSize(width: 320, height: 100)
    
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
                state.refreshFoldingRanges()
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
                gutterDecorationsOverlay
            }
            .overlay(alignment: .topLeading) {
                surfaceHighlightsOverlay
            }
            .overlay(alignment: .topLeading) {
                secondaryCursorOverlay
            }
            .overlay(alignment: .topLeading) {
                GeometryReader { proxy in
                    inlinePresentationsOverlay(in: proxy.size)
                }
            }
            .overlay(alignment: .topLeading) {
                GeometryReader { proxy in
                    hoverPreview(in: proxy.size)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                peekOverlay
            }
            .overlay(alignment: .top) {
                inlineRenameOverlay
            }
            .overlay(alignment: .topTrailing) {
                foldingSummaryOverlay
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
        GeometryReader { proxy in
            if let textView = state.focusedTextView,
               let lineTable = contentLineTable,
               let placement = state.codeActionIndicatorPlacement(
                    textView: textView,
                    lineTable: lineTable,
                    containerSize: proxy.size
               ) {
                let actions = state.currentCodeActionOverlayActions
                VStack(alignment: .leading, spacing: 0) {
                    codeActionIndicatorButton(actionCount: actions.count)
                        .offset(x: placement.origin.x, y: placement.origin.y)

                    if state.isCodeActionPanelPresented {
                        CodeActionPanel(
                            actions: actions,
                            selectedIndex: Binding(
                                get: { state.selectedCodeActionIndex },
                                set: { state.selectCodeAction(at: $0) }
                            )
                        ) { action in
                            Task { @MainActor in
                                await state.performCodeActionOverlayAction(action)
                            }
                        }
                        .offset(x: placement.panelOrigin.x, y: placement.panelOrigin.y)
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topLeading)))
                    }
                }
                .animation(.easeOut(duration: 0.14), value: state.isCodeActionPanelPresented)
            }
        }
    }

    private func codeActionIndicatorButton(actionCount: Int) -> some View {
        let style = EditorCodeActionOverlayStyle.standard
        return Button {
            state.toggleCodeActionPanel()
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: style.indicatorCornerRadius)
                    .fill(AppUI.Color.semantic.warning.opacity(state.isCodeActionPanelPresented ? 0.24 : 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: style.indicatorCornerRadius)
                            .stroke(AppUI.Color.semantic.warning.opacity(state.isCodeActionPanelPresented ? 0.7 : 0.45), lineWidth: 1)
                    )
                    .frame(width: style.indicatorSize, height: style.indicatorSize)

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.warning)

                if actionCount > 1 {
                    Text("\(actionCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(AppUI.Color.semantic.primary)
                        )
                        .offset(x: 8, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Quick Fix")
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
    private var gutterDecorationsOverlay: some View {
        let decorations = visibleGutterDecorations
        if !decorations.isEmpty {
            ZStack(alignment: .topLeading) {
                ForEach(decorations) { decoration in
                    gutterDecorationView(decoration)
                        .frame(width: decoration.rect.width, height: decoration.rect.height)
                        .offset(x: decoration.rect.minX, y: decoration.rect.minY)
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func gutterDecorationView(_ decoration: EditorGutterDecoration) -> some View {
        ZStack {
            switch decoration.style.shape {
            case .circle:
                Circle()
                    .fill(decoration.style.fillColor)
                    .overlay(
                        Circle()
                            .stroke(decoration.style.strokeColor, lineWidth: 1)
                    )
            case .roundedRect:
                RoundedRectangle(cornerRadius: decoration.style.cornerRadius)
                    .fill(decoration.style.fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: decoration.style.cornerRadius)
                            .stroke(decoration.style.strokeColor, lineWidth: 1)
                    )
            case .bar:
                Capsule()
                    .fill(decoration.style.fillColor)
                    .overlay(
                        Capsule()
                            .stroke(decoration.style.strokeColor, lineWidth: 0.75)
                    )
            }

            if let badgeText = decoration.badgeText {
                Text(badgeText)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(decoration.style.foregroundColor)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.horizontal, decoration.style.shape == .bar ? 0 : 1)
            } else if let symbolName = decoration.symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 5.5, weight: .bold))
                    .foregroundColor(decoration.style.foregroundColor)
            }
        }
    }

    @ViewBuilder
    private var surfaceHighlightsOverlay: some View {
        let highlights = visibleSurfaceHighlights
        if !highlights.isEmpty {
            ZStack(alignment: .topLeading) {
                ForEach(highlights) { highlight in
                    RoundedRectangle(cornerRadius: highlight.style.cornerRadius)
                        .fill(highlight.style.fillColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: highlight.style.cornerRadius)
                                .stroke(highlight.style.strokeColor, lineWidth: highlight.style.lineWidth)
                        )
                        .frame(
                            width: max(highlight.rect.width, highlight.style.minimumWidth),
                            height: max(highlight.rect.height, highlight.style.minimumHeight)
                        )
                        .offset(x: highlight.rect.minX, y: highlight.rect.minY)
                        .zIndex(highlight.style.zIndex)
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var secondaryCursorOverlay: some View {
        let highlights = visibleSecondaryCursorHighlights
        if !highlights.isEmpty {
            ZStack(alignment: .topLeading) {
                ForEach(highlights) { highlight in
                    RoundedRectangle(cornerRadius: highlight.cornerRadius)
                        .fill(highlight.fillColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: highlight.cornerRadius)
                                .stroke(
                                    highlight.strokeColor,
                                    style: StrokeStyle(lineWidth: highlight.lineWidth, dash: highlight.dash)
                                )
                        )
                        .frame(width: max(highlight.rect.width, 2), height: max(highlight.rect.height, 2))
                        .offset(x: highlight.rect.minX, y: highlight.rect.minY)
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func inlinePresentationsOverlay(in containerSize: CGSize) -> some View {
        if let textView = state.focusedTextView,
           let lineTable = contentLineTable {
            let style = EditorInlinePresentationStyle.standard
            let presentations = state.inlinePresentations(
                textView: textView,
                lineTable: lineTable,
                containerSize: containerSize
            )

            ZStack(alignment: .topLeading) {
                ForEach(presentations) { presentation in
                    HStack(spacing: 6) {
                        Image(systemName: presentation.iconName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(presentation.style.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(presentation.title)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .lineLimit(1)

                            if let detail = presentation.detail {
                                Text(detail)
                                    .font(.system(size: 9))
                                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        if let badgeText = presentation.badgeText {
                            Text(badgeText)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(presentation.style.accentColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(presentation.style.accentColor.opacity(0.12))
                                )
                        }
                    }
                    .foregroundColor(presentation.style.foregroundColor)
                    .padding(.horizontal, style.horizontalPadding)
                    .padding(.vertical, style.verticalPadding)
                    .frame(width: presentation.size.width, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: style.cornerRadius)
                            .fill(presentation.style.backgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: style.cornerRadius)
                                    .stroke(
                                        presentation.style.borderColor,
                                        lineWidth: style.borderWidth
                                    )
                            )
                    )
                    .offset(x: presentation.origin.x, y: presentation.origin.y)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                }
            }
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.14), value: presentations.map(\.id))
        }
    }

    @ViewBuilder
    private var foldingSummaryOverlay: some View {
        if let summary = state.currentFoldingSummary {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppUI.Color.semantic.textPrimary)
                    Text(summary.subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .lineLimit(1)
                }

                Text(summary.badgeText)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppUI.Color.semantic.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(AppUI.Color.semantic.primary.opacity(0.12))
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppUI.Color.semantic.textTertiary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppUI.Color.semantic.textTertiary.opacity(0.16), lineWidth: 1)
                    )
            )
            .padding(.top, 10)
            .padding(.trailing, 14)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity
            ))
            .animation(.easeOut(duration: 0.16), value: summary)
        }
    }

    // MARK: - Hover Popover

    @ViewBuilder
    private func hoverPreview(in containerSize: CGSize) -> some View {
        if let hoverText = state.currentHoverOverlayText {
            let style = EditorHoverOverlayStyle.standard
            let placement = state.hoverOverlayPlacement(
                in: containerSize,
                popoverSize: hoverPopoverSize,
                style: style
            )

            HoverPopoverView(markdownText: hoverText)
                .frame(
                    width: placement.cardSize.width,
                    height: placement.cardSize.height,
                    alignment: .topLeading
                )
                .onAppear {
                    if EditorPlugin.verbose {
                        EditorPlugin.logger.debug("\(Self.t)悬停预览: 内容长度=\(hoverText.count), 矩形=\(String(describing: state.currentHoverOverlayRect))")
                        EditorPlugin.logger.debug("\(Self.t)悬停预览: 原始内容=\n\(hoverText)")
                    }
                }
                .fixedSize(horizontal: false, vertical: false)
                .background(
                    GeometryReader { popoverGeo in
                        Color.clear
                            .onAppear {
                                hoverPopoverSize = popoverGeo.size
                            }
                            .onChange(of: popoverGeo.size) { _, newSize in
                                hoverPopoverSize = newSize
                            }
                    }
                )
                .offset(
                    x: placement.origin.x,
                    y: placement.origin.y
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: placement.isPresentedAboveSymbol ? .bottomLeading : .topLeading)),
                    removal: .opacity
                ))
                .animation(.easeOut(duration: 0.14), value: state.currentHoverOverlayText)
                .animation(.easeOut(duration: 0.12), value: placement.origin)
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
        adapter.configuration(
            for: state,
            completionDelegate: completionDelegate
        )
    }
}
