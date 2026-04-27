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
    
    /// 编辑器协调器（使用 @State 确保在 View 更新间保持同一实例）
    @State private var textCoordinator: EditorCoordinator?
    @State private var cursorCoordinator: CursorCoordinator?
    @State private var scrollCoordinator: ScrollCoordinator?
    @State private var contextMenuCoordinator: ContextMenuCoordinator?
    @State private var semanticTokenProvider: SemanticTokenHighlightProvider?
    @State private var documentHighlightProvider: DocumentHighlightHighlighter?
    @State private var signatureHelpProvider = SignatureHelpProvider()
    @State private var codeActionPanelPresented: Bool = false
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
    
    /// 缓存的 popover 高度，用于在上方定位时避免遮挡
    @State private var hoverPopoverHeight: CGFloat = 100
    
    init(state: EditorState) {
        self._state = ObservedObject(wrappedValue: state)
    }
    
    var body: some View {
        editorContent
            .onAppear {
                initializeCoordinators()
                wireDelegates()
            }
            .onChange(of: state.fontSize) { _, _ in updateConfigCache() }
            .onChange(of: state.wrapLines) { _, _ in updateConfigCache() }
            .onChange(of: state.showGutter) { _, _ in updateConfigCache() }
            .onChange(of: state.showMinimap) { _, _ in updateConfigCache() }
            .onChange(of: state.showFoldingRibbon) { _, _ in updateConfigCache() }
            .onChange(of: state.tabWidth) { _, _ in updateConfigCache() }
            .onChange(of: state.useSpaces) { _, _ in updateConfigCache() }
            .onChange(of: state.currentThemeId) { _, _ in updateConfigCache() }
            .onChange(of: state.currentTheme) { _, _ in updateConfigCache() }
            .onChange(of: state.content) { _, newContent in
                jumpDelegate.textStorage = newContent
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
                    state: multiCursorSafeBinding,
                    highlightProviders: activeHighlightProviders,
                    coordinators: activeCoordinators,
                    completionDelegate: completionDelegate,
                    jumpToDefinitionDelegate: jumpDelegate
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                inlayHintsStrip
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
        if let help = state.signatureHelpProvider.currentHelp {
            SignatureHelpView(item: help)
                .padding(.leading, 12)
                .padding(.bottom, 32)
        }
    }
    
    @ViewBuilder
    private var codeActionOverlay: some View {
        if state.codeActionProvider.isVisible {
            CodeActionPanel(
                actions: state.codeActionProvider.actions
            ) { action in
                Task { @MainActor in
                    await state.codeActionProvider.performAction(
                        action,
                        textView: state.focusedTextView,
                        documentURL: state.currentFileURL
                    ) { message in
                        state.showStatusToast(message, level: .warning)
                    }
                    state.codeActionProvider.clear()
                }
            }
            .padding(.leading, 12)
            .padding(.top, 48)
        }
    }

    @ViewBuilder
    private var inlayHintsStrip: some View {
        let hints = state.inlayHintProvider.hints
        if hints.isEmpty {
            EmptyView()
        } else {
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

    // MARK: - Hover Popover

    @ViewBuilder
    private func hoverPreview(in containerSize: CGSize) -> some View {
        if let hoverText = state.panelState.mouseHoverContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !hoverText.isEmpty {
            HoverPopoverView(markdownText: hoverText)
                .onAppear {
                    if EditorPlugin.verbose {
                        EditorPlugin.logger.debug("\(Self.t)悬停预览: 内容长度=\(hoverText.count), 矩形=\(String(describing: self.state.panelState.mouseHoverSymbolRect))")
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
                .offset(hoverOffset(in: containerSize))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)),
                    removal: .opacity
                ))
                .animation(.easeOut(duration: 0.14), value: state.panelState.mouseHoverContent)
                .animation(.easeOut(duration: 0.12), value: state.panelState.mouseHoverSymbolRect)
        }
    }

    /// 计算 hover popover 的偏移量
    /// 核心策略：popover 显示在 symbol 的正上方，左对齐 symbol 起点
    private func hoverOffset(in containerSize: CGSize) -> CGSize {
        let symbolRect = state.panelState.mouseHoverSymbolRect
        let popoverEstimatedHeight = hoverPopoverHeight
        let popoverMaxWidth: CGFloat = 440
        let verticalGap: CGFloat = 4  // popover 与 symbol 之间的间距

        // X: 左对齐 symbol 起点，但不超出容器
        let preferredX = symbolRect.minX
        let clampedX = max(4, min(preferredX, containerSize.width - popoverMaxWidth - 4))

        // Y: 放在 symbol 上方
        let preferredY = symbolRect.minY - popoverEstimatedHeight - verticalGap

        // 如果上方空间不足，则放到 symbol 下方
        let fallbackY = symbolRect.maxY + verticalGap
        let clampedY: CGFloat
        if preferredY >= 4 {
            clampedY = preferredY
        } else {
            clampedY = min(fallbackY, max(containerSize.height - popoverEstimatedHeight - 4, 4))
        }

        return CGSize(width: clampedX, height: clampedY)
    }

    // MARK: - Initialization & Delegates

    /// 首次出现时初始化协调器和配置缓存
    private func initializeCoordinators() {
        if textCoordinator == nil {
            textCoordinator = EditorCoordinator(state: state)
        }
        if cursorCoordinator == nil {
            cursorCoordinator = CursorCoordinator(state: state)
        }
        if scrollCoordinator == nil {
            scrollCoordinator = ScrollCoordinator(state: state)
        }
        if contextMenuCoordinator == nil {
            contextMenuCoordinator = ContextMenuCoordinator(state: state)
        }
        if semanticTokenProvider == nil {
            semanticTokenProvider = SemanticTokenHighlightProvider(
                lspService: state.lspServiceInstance,
                uriProvider: { [weak state] in
                    state?.currentFileURL?.absoluteString
                }
            )
        }
        if documentHighlightProvider == nil {
            documentHighlightProvider = DocumentHighlightHighlighter(
                provider: state.documentHighlightProvider
            )
        }
        if cachedConfig == nil {
            updateConfigCache()
        }
        if hoverCoordinator == nil {
            hoverCoordinator = HoverEditorCoordinator(state: state)
        }
    }

    private func wireDelegates() {
        jumpDelegate.textStorage = state.content
        jumpDelegate.treeSitterClient = treeSitterClient
        jumpDelegate.lspClient = state.lspClient
        jumpDelegate.currentFileURLProvider = { [weak state] in
            state?.currentFileURL
        }
        jumpDelegate.onOpenExternalDefinition = { [weak state] url, target in
            state?.performNavigation(.definition(url, target, highlightLine: false))
        }
        state.jumpDelegate = jumpDelegate
        
        textCoordinator?.jumpDelegate = jumpDelegate
        
        completionDelegate.lspClient = state.lspClient
        completionDelegate.editorExtensionRegistry = state.editorExtensions
        completionDelegate.editorState = state
    }
    
    // MARK: - Configuration Management
    
    private func updateConfigCache() {
        cachedConfig = buildConfiguration()
    }
    
    // MARK: - Language
    
    private var resolvedLanguage: CodeLanguage {
        state.detectedLanguage ?? CodeLanguage.allLanguages.first { $0.tsName == "swift" } ?? CodeLanguage.allLanguages[0]
    }
    
    private var activeHighlightProviders: [any HighlightProviding] {
        var providers: [any HighlightProviding] = [treeSitterClient]
        if let semanticTokenProvider {
            providers.insert(semanticTokenProvider, at: 0)
        }
        if let documentHighlightProvider {
            providers.append(documentHighlightProvider)
        }
        return providers
    }
    
    private var activeCoordinators: [TextViewCoordinator] {
        var result: [TextViewCoordinator] = []
        if let textCoordinator { result.append(textCoordinator) }
        if let cursorCoordinator { result.append(cursorCoordinator) }
        if let scrollCoordinator { result.append(scrollCoordinator) }
        if let contextMenuCoordinator { result.append(contextMenuCoordinator) }
        if let hoverCoordinator { result.append(hoverCoordinator) }
        return result
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
    private var multiCursorSafeBinding: Binding<SourceEditorState> {
        Binding<SourceEditorState>(
            get: {
                var result = state.editorState
                result.scrollPosition = nil
                return result
            },
            set: { newState in
                let update = EditorSourceEditorBindingController.update(
                    from: newState,
                    multiCursorSelectionCount: state.multiCursorState.all.count,
                    currentFindReplaceState: state.activeSession.findReplaceState
                )

                DispatchQueue.main.async {
                    state.applySourceEditorBindingUpdate(update)
                }
            }
        )
    }

    @MainActor
    private func buildConfiguration() -> SourceEditorConfiguration {
        let fontSize = CGFloat(state.fontSize)
        let lineHeightMultiple = 1.2
        
        return SourceEditorConfiguration(
            appearance: .init(
                theme: state.currentTheme ?? EditorThemeAdapter.fallbackTheme(),
                useThemeBackground: true,
                font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                lineHeightMultiple: lineHeightMultiple,
                letterSpacing: 1.0,
                wrapLines: state.wrapLines,
                useSystemCursor: true,
                tabWidth: state.tabWidth,
                bracketPairEmphasis: .flash
            ),
            behavior: .init(
                isEditable: state.isEditable,
                indentOption: state.useSpaces
                    ? .spaces(count: state.tabWidth)
                    : .tab
            ),
            layout: .init(
                editorOverscroll: 0.1,
                contentInsets: nil,
                additionalTextInsets: nil
            ),
            peripherals: .init(
                showGutter: state.showGutter,
                showMinimap: state.showMinimap,
                showFoldingRibbon: state.showFoldingRibbon,
                codeSuggestionTriggerCharacters: completionDelegate.completionTriggerCharacters()
            )
        )
    }
}
