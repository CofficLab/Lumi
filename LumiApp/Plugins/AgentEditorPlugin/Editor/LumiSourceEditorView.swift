import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import MagicKit

/// 代码编辑器主视图
/// 基于 CodeEditSourceEditor 实现专业级编辑体验
struct LumiSourceEditorView: View {
    
    @ObservedObject var state: LumiEditorState
    
    /// 编辑器协调器（使用 @State 确保在 View 更新间保持同一实例）
    /// 之前作为普通 let 属性，每次 View struct 重建时会创建新实例，
    /// 导致旧实例被 ARC 释放，TextViewController 中的 WeakCoordinator 弱引用失效，
    /// coordinator 回调不再被触发，自动保存失效。
    @State private var textCoordinator: LumiEditorCoordinator?
    @State private var cursorCoordinator: LumiCursorCoordinator?
    @State private var contextMenuCoordinator: LumiContextMenuCoordinator?
    
    /// 跳转到定义代理（Cmd+Click）
    @StateObject private var jumpDelegate = LumiJumpToDefinitionDelegate()
    
    /// tree-sitter 客户端
    @State private var treeSitterClient = TreeSitterClient()
    
    /// 缓存的配置（避免每次 body 重渲染都创建新对象导致 reloadUI）
    /// 使用 @State 确保只初始化一次
    @State private var cachedConfig: SourceEditorConfiguration?
    
    init(state: LumiEditorState) {
        self._state = ObservedObject(wrappedValue: state)
    }
    
    var body: some View {
        editorContent
            .onAppear {
                initializeCoordinators()
                // 初始化跳转定义代理
                jumpDelegate.textStorage = state.content
                jumpDelegate.treeSitterClient = treeSitterClient
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
                jumpDelegate.treeSitterClient = treeSitterClient
            }
    }

    /// 编辑器主体内容（拆分为独立视图以减轻编译器类型推断负担）
    @ViewBuilder
    private var editorContent: some View {
        if let content = state.content,
           let textCoordinator,
           let cursorCoordinator,
           let contextMenuCoordinator {
            let config = cachedConfig ?? buildConfiguration()
            SourceEditor(
                content,
                language: resolvedLanguage,
                configuration: config,
                state: $state.editorState,
                highlightProviders: [treeSitterClient],
                coordinators: [textCoordinator, cursorCoordinator, contextMenuCoordinator],
                jumpToDefinitionDelegate: jumpDelegate
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("No content")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 首次出现时初始化协调器和配置缓存
    private func initializeCoordinators() {
        if textCoordinator == nil {
            textCoordinator = LumiEditorCoordinator(state: state)
        }
        if cursorCoordinator == nil {
            cursorCoordinator = LumiCursorCoordinator(state: state)
        }
        if contextMenuCoordinator == nil {
            contextMenuCoordinator = LumiContextMenuCoordinator(state: state)
        }
        if cachedConfig == nil {
            updateConfigCache()
        }
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
    
    // MARK: - Configuration
    
    /// 构建编辑器配置
    @MainActor
    private func buildConfiguration() -> SourceEditorConfiguration {
        let fontSize = CGFloat(state.fontSize)
        let lineHeightMultiple = 1.2  // 使用稍大的行高，确保显示正常
        
        return SourceEditorConfiguration(
            appearance: .init(
                theme: state.currentTheme ?? LumiEditorThemeAdapter.theme(from: .xcodeDark),
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
                showFoldingRibbon: state.showFoldingRibbon
            )
        )
    }
}
