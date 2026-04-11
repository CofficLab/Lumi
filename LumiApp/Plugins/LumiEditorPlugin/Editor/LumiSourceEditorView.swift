import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import MagicKit

/// 代码编辑器主视图
/// 基于 CodeEditSourceEditor 实现专业级编辑体验
struct LumiSourceEditorView: View {
    
    @ObservedObject var state: LumiEditorState
    
    /// 编辑器协调器
    private let textCoordinator: LumiEditorCoordinator
    private let cursorCoordinator: LumiCursorCoordinator
    private let contextMenuCoordinator: LumiContextMenuCoordinator
    
    /// tree-sitter 客户端
    @State private var treeSitterClient = TreeSitterClient()
    
    /// 缓存的配置（避免每次 body 重渲染都创建新对象导致 reloadUI）
    /// 使用 @State 确保只初始化一次
    @State private var cachedConfig: SourceEditorConfiguration?
    
    init(state: LumiEditorState) {
        self._state = ObservedObject(wrappedValue: state)
        self.textCoordinator = LumiEditorCoordinator(state: state)
        self.cursorCoordinator = LumiCursorCoordinator(state: state)
        self.contextMenuCoordinator = LumiContextMenuCoordinator(state: state)
    }
    
    var body: some View {
        // 直接读取缓存，不在 body 中写 @State（避免 "Modifying state during view update"）
        let config = cachedConfig ?? buildConfiguration()
        
        Group {
            if let content = state.content {
                SourceEditor(
                    content,
                    language: resolvedLanguage,
                    configuration: config,
                    state: $state.editorState,
                    highlightProviders: [treeSitterClient],
                    coordinators: [textCoordinator, cursorCoordinator, contextMenuCoordinator]
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No content")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // 关键：当这些值变化时，重建配置（在 onChange / onAppear 中写 @State 是安全的）
        .onChange(of: state.fontSize) { _, _ in updateConfigCache() }
        .onChange(of: state.wrapLines) { _, _ in updateConfigCache() }
        .onChange(of: state.showGutter) { _, _ in updateConfigCache() }
        .onChange(of: state.showMinimap) { _, _ in updateConfigCache() }
        .onChange(of: state.showFoldingRibbon) { _, _ in updateConfigCache() }
        .onChange(of: state.tabWidth) { _, _ in updateConfigCache() }
        .onChange(of: state.useSpaces) { _, _ in updateConfigCache() }
        .onChange(of: state.themePreset) { _, _ in updateConfigCache() }
        .onChange(of: state.currentTheme) { _, _ in updateConfigCache() }
        .onAppear {
            // 首次出现时确保缓存已建立
            if cachedConfig == nil { updateConfigCache() }
        }
    }
    
    // MARK: - Configuration Management
    
    // getConfiguration() 已移除——body 直接读 cachedConfig ?? buildConfiguration()
    
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
