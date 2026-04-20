import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import MagicKit

/// 代码编辑器主视图
/// 基于 CodeEditSourceEditor 实现专业级编辑体验
struct SourceEditorView: View {
    
    @ObservedObject var state: EditorState
    
    /// 编辑器协调器（使用 @State 确保在 View 更新间保持同一实例）
    /// 之前作为普通 let 属性，每次 View struct 重建时会创建新实例，
    /// 导致旧实例被 ARC 释放，TextViewController 中的 WeakCoordinator 弱引用失效，
    /// coordinator 回调不再被触发，自动保存失效。
    @State private var textCoordinator: EditorCoordinator?
    @State private var cursorCoordinator: CursorCoordinator?
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
            .onChange(of: state.themePreset) { _, _ in updateConfigCache() }
            .onChange(of: state.currentTheme) { _, _ in updateConfigCache() }
            .onChange(of: state.content) { _, newContent in
                jumpDelegate.textStorage = newContent
            }
            .onChange(of: state.currentFileURL) { _, _ in
                updateConfigCache()
            }
    }

    /// 编辑器主体内容（拆分为独立视图以减轻编译器类型推断负担）
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

    @ViewBuilder
    private func hoverPreview(in containerSize: CGSize) -> some View {
        if let hoverText = state.mouseHoverContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !hoverText.isEmpty {
            Text(hoverAttributedText(from: hoverText))
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(10)
                .multilineTextAlignment(.leading)
                .padding(10)
                .frame(maxWidth: 440, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
                        )
                )
                .offset(hoverOffset(in: containerSize))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .topLeading)),
                    removal: .opacity
                ))
                .animation(.easeOut(duration: 0.14), value: state.mouseHoverContent)
                .animation(.easeOut(duration: 0.12), value: state.mouseHoverPoint)
        }
    }

    private func hoverOffset(in containerSize: CGSize) -> CGSize {
        let preferredX = state.mouseHoverPoint.x + 12
        let preferredY = state.mouseHoverPoint.y + 18
        let maxWidth = max(containerSize.width - 460, 8)
        let maxHeight = max(containerSize.height - 220, 8)
        return CGSize(
            width: min(max(preferredX, 8), maxWidth),
            height: min(max(preferredY, 8), maxHeight)
        )
    }

    private func hoverAttributedText(from markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attributed = try? AttributedString(markdown: markdown, options: options) {
            return attributed
        }
        return AttributedString(markdown)
    }

    /// 首次出现时初始化协调器和配置缓存
    private func initializeCoordinators() {
        print("🔧 [AutoSave] initializeCoordinators | textCoordinator=\(textCoordinator != nil) | cursorCoordinator=\(cursorCoordinator != nil) | contextMenuCoordinator=\(contextMenuCoordinator != nil) | content=\(state.content != nil) | fileURL=\(state.currentFileURL?.lastPathComponent ?? "nil")")
        if textCoordinator == nil {
            textCoordinator = EditorCoordinator(state: state)
            print("🔧 [AutoSave] 创建了新的 EditorCoordinator")
        }
        if cursorCoordinator == nil {
            cursorCoordinator = CursorCoordinator(state: state)
        }
        if contextMenuCoordinator == nil {
            contextMenuCoordinator = ContextMenuCoordinator(state: state)
        }
        if semanticTokenProvider == nil {
            semanticTokenProvider = SemanticTokenHighlightProvider(uriProvider: { [weak state] in
                state?.currentFileURL?.absoluteString
            })
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
        jumpDelegate.lspCoordinator = state.lspCoordinator
        jumpDelegate.currentFileURLProvider = { [weak state] in
            state?.currentFileURL
        }
        jumpDelegate.onOpenExternalDefinition = { [weak state] url, target in
            state?.openDefinitionLocation(url: url, target: target)
        }
        state.jumpDelegate = jumpDelegate
        
        // 将 jumpDelegate 注入 coordinator，供非隔离方法使用
        textCoordinator?.jumpDelegate = jumpDelegate
        
        completionDelegate.lspCoordinator = state.lspCoordinator
        completionDelegate.editorState = state
    }
    
    // MARK: - Configuration Management
    
    /// 强制更新配置缓存
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
        if let contextMenuCoordinator { result.append(contextMenuCoordinator) }
        if let hoverCoordinator { result.append(hoverCoordinator) }
        return result
    }
    
    // MARK: - Configuration
    
    /// 提供给 SourceEditor 的安全 Binding。
    ///
    /// ## 解决的问题
    ///
    /// ### 1. 滚动位置反馈循环（"有人在抢滚动条"）
    ///
    /// 循环路径（修复前）：
    ///   用户滚动 → boundsDidChange → Coordinator 回写 scrollPosition 到 @Binding
    ///   → SwiftUI updateNSViewController → scrollView.scroll(to:) → 又触发 boundsDidChange
    ///
    /// 根因：Coordinator 通过 `updateState { $0.scrollPosition = ... }` 修改 `@Binding`，
    /// SwiftUI 检测到 binding 变化后调用 updateNSViewController。
    /// 正常情况下 `isUpdateFromTextView` 标志位能阻止循环，
    /// 但 `EditorState.editorState` 是 `@Published`，binding 的 set 回调又通过
    /// `DispatchQueue.main.async` 延迟写回了 scrollPosition，
    /// 导致第二轮 updateNSViewController 时标志位已重置，scrollView 被强制滚回旧位置。
    ///
    /// 修复：**不在 get 中返回 scrollPosition**，始终返回 nil。
    /// 这样 SourceEditor 的 updateControllerWithState 永远不会因为 binding 中的
    /// scrollPosition 而强制设置滚动位置。NSScrollView 的滚动完全由用户操作控制。
    /// 外部的滚动跳转（如跳转到定义）通过设置 cursorPositions 实现，
    /// CodeEditSourceEditor 的 setCursorPositions 会自动滚动到光标位置。
    ///
    /// ### 2. Publishing changes from within view updates
    ///
    /// Binding 的 set 闭包可能在 updateNSViewController 调用栈中被触发。
    /// 修复：使用 DispatchQueue.main.async 延迟所有 @Published 属性修改。
    ///
    /// ### 3. 多光标模式下光标丢失
    ///
    /// updateCursorPosition() 可能跳过可见区域外的 selection，导致 cursorPositions
    /// 数量少于 textSelections。修复：多光标模式下忽略 cursorPositions 回写。
    private var multiCursorSafeBinding: Binding<SourceEditorState> {
        Binding<SourceEditorState>(
            get: {
                // 关键：scrollPosition 始终返回 nil，切断滚动反馈循环。
                // SourceEditor 的 updateControllerWithState 会因为 scrollPosition == nil
                // 而跳过 scrollView.scroll(to:) 调用。
                var result = state.editorState
                result.scrollPosition = nil
                return result
            },
            set: { newState in
                if state.multiCursorState.all.count > 1 {
                    // 多光标模式：不回写 scrollPosition 和 cursorPositions
                    DispatchQueue.main.async {
                        state.editorState.findText = newState.findText
                        state.editorState.replaceText = newState.replaceText
                        state.editorState.findPanelVisible = newState.findPanelVisible
                    }
                } else {
                    // 单光标模式：不回写 scrollPosition
                    DispatchQueue.main.async {
                        state.editorState.cursorPositions = newState.cursorPositions
                        state.editorState.findText = newState.findText
                        state.editorState.replaceText = newState.replaceText
                        state.editorState.findPanelVisible = newState.findPanelVisible
                    }
                }
            }
        )
    }

    /// 构建编辑器配置
    @MainActor
    private func buildConfiguration() -> SourceEditorConfiguration {
        let fontSize = CGFloat(state.fontSize)
        let lineHeightMultiple = 1.2  // 使用稍大的行高，确保显示正常
        
        return SourceEditorConfiguration(
            appearance: .init(
                theme: state.currentTheme ?? EditorThemeAdapter.theme(from: .xcodeDark),
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
                additionalTextInsets: nil  // 不使用额外的文本内边距
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
