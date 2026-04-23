import Foundation
import LanguageServerProtocol

/// 编辑器面板状态
///
/// 管理各种编辑器面板的显示状态和数据源。
/// 与 UI 配置和文件状态解耦。
///
/// ## 职责范围
/// - Problems 面板（诊断信息）
/// - References 面板（引用查找结果）
/// - 工作区符号搜索面板
/// - 调用层级面板
///
/// ## 线程模型
/// 标记 `@MainActor`，所有属性更新在主线程执行。
@MainActor
final class EditorPanelState: ObservableObject {

    // MARK: - Problems 面板

    /// 当前文件的诊断列表
    @Published var problemDiagnostics: [Diagnostic] = []

    /// 当前选中的问题
    @Published var selectedProblemDiagnostic: Diagnostic?

    /// 是否展示 Problems 面板
    @Published var isProblemsPanelPresented: Bool = false

    // MARK: - References 面板

    /// LSP 引用查询结果
    @Published var referenceResults: [EditorReferenceResult] = []

    /// 是否展示 References 面板
    @Published var isReferencePanelPresented: Bool = false

    // MARK: - 工作区符号搜索

    /// 是否展示工作区符号搜索面板
    @Published var isWorkspaceSymbolSearchPresented: Bool = false

    // MARK: - 调用层级

    /// 是否展示调用层级面板
    @Published var isCallHierarchyPresented: Bool = false

    // MARK: - Hover 状态

    /// 鼠标悬停 Hover 内容（Markdown 格式）
    @Published var mouseHoverContent: String?

    /// 鼠标悬停对应的 symbol 矩形（编辑器坐标系）
    @Published var mouseHoverSymbolRect: CGRect = .zero

    // MARK: - 便捷方法

    /// 设置鼠标悬停状态
    func setMouseHover(content: String, symbolRect: CGRect) {
        let currentContent = mouseHoverContent ?? ""
        let currentRect = mouseHoverSymbolRect
        let epsilon: CGFloat = 0.75
        let isSameContent = currentContent == content
        let isCloseRect = abs(currentRect.minX - symbolRect.minX) <= epsilon &&
            abs(currentRect.minY - symbolRect.minY) <= epsilon &&
            abs(currentRect.width - symbolRect.width) <= epsilon &&
            abs(currentRect.height - symbolRect.height) <= epsilon
        if isSameContent && isCloseRect { return }

        mouseHoverContent = content
        mouseHoverSymbolRect = symbolRect
    }

    /// 清除鼠标悬停状态
    func clearMouseHover() {
        guard mouseHoverContent != nil || mouseHoverSymbolRect != .zero else { return }
        mouseHoverContent = nil
        mouseHoverSymbolRect = .zero
    }

    /// 切换 Problems 面板
    func toggleProblemsPanel() {
        if isProblemsPanelPresented {
            isProblemsPanelPresented = false
        } else {
            isReferencePanelPresented = false
            isProblemsPanelPresented = true
        }
    }

    /// 关闭 Problems 面板
    func closeProblemsPanel() {
        isProblemsPanelPresented = false
    }

    /// 关闭 References 面板
    func closeReferencePanel() {
        isReferencePanelPresented = false
    }

    /// 关闭工作区符号搜索
    func closeWorkspaceSymbolSearch() {
        isWorkspaceSymbolSearchPresented = false
    }

    /// 关闭调用层级面板
    func closeCallHierarchy() {
        isCallHierarchyPresented = false
    }

    // MARK: - 重置

    func reset() {
        problemDiagnostics = []
        selectedProblemDiagnostic = nil
        isProblemsPanelPresented = false
        referenceResults = []
        isReferencePanelPresented = false
        isWorkspaceSymbolSearchPresented = false
        isCallHierarchyPresented = false
        mouseHoverContent = nil
        mouseHoverSymbolRect = .zero
    }
}

/// LSP 引用查询结果
struct EditorReferenceResult: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let line: Int
    let column: Int
    let path: String
    let preview: String
}
