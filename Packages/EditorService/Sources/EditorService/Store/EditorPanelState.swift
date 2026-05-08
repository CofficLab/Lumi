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
public final class EditorPanelState: ObservableObject {

    // MARK: - Open Editors 面板

    /// 是否展示 Open Editors 面板
    @Published var isOpenEditorsPanelPresented: Bool = false

    /// 是否展示 Outline 面板
    @Published var isOutlinePanelPresented: Bool = false

    // MARK: - Problems 面板

    /// 当前文件的诊断列表
    @Published public var problemDiagnostics: [Diagnostic] = []

    /// 当前文件的项目语义问题
    @Published public var semanticProblems: [EditorSemanticProblem] = []

    /// 当前选中的问题
    @Published var selectedProblemDiagnostic: Diagnostic?

    /// 是否展示 Problems 面板
    @Published var isProblemsPanelPresented: Bool = false

    // MARK: - References 面板

    /// LSP 引用查询结果
    @Published public var referenceResults: [EditorReferenceResult] = []

    /// 当前选中的引用项
    @Published public var selectedReferenceResult: EditorReferenceResult?

    /// 是否展示 References 面板
    @Published var isReferencePanelPresented: Bool = false

    // MARK: - 工作区文本搜索

    @Published public var workspaceSearchQuery: String = ""
    @Published public var workspaceSearchResults: [EditorWorkspaceSearchFileResult] = []
    @Published public var workspaceSearchSummary: EditorWorkspaceSearchSummary?
    @Published public var workspaceSearchErrorMessage: String?
    @Published public var workspaceSearchCollapsedFilePaths = Set<String>()
    @Published public var selectedWorkspaceSearchMatchID: String?
    @Published public var isWorkspaceSearchLoading: Bool = false
    @Published var isWorkspaceSearchPresented: Bool = false

    // MARK: - 工作区符号搜索

    /// 是否展示工作区符号搜索面板
    @Published public var isWorkspaceSymbolSearchPresented: Bool = false

    // MARK: - 调用层级

    /// 是否展示调用层级面板
    @Published public var isCallHierarchyPresented: Bool = false

    // MARK: - Hover 状态

    /// 鼠标悬停 Hover 内容（Markdown 格式）
    @Published public var mouseHoverContent: String?

    /// 鼠标悬停对应的 symbol 矩形（编辑器坐标系）
    @Published public var mouseHoverSymbolRect: CGRect = .zero

    /// 鼠标悬停对应的 LSP Range（用于在编辑器中高亮被 hover 的符号）
    @Published public var mouseHoverRange: LSPRange?

    var snapshot: EditorPanelSnapshot {
        EditorPanelSnapshot(
            isOpenEditorsPanelPresented: isOpenEditorsPanelPresented,
            isOutlinePanelPresented: isOutlinePanelPresented,
            isProblemsPanelPresented: isProblemsPanelPresented,
            isReferencePanelPresented: isReferencePanelPresented,
            isWorkspaceSearchPresented: isWorkspaceSearchPresented,
            isWorkspaceSymbolSearchPresented: isWorkspaceSymbolSearchPresented,
            isCallHierarchyPresented: isCallHierarchyPresented
        )
    }

    var sessionState: EditorPanelSessionState {
        EditorPanelSessionState(
            mouseHoverContent: mouseHoverContent,
            mouseHoverSymbolRect: mouseHoverSymbolRect,
            referenceResults: referenceResults.map(Self.referenceResult(from:)),
            selectedReferenceResult: selectedReferenceResult.map(Self.referenceResult(from:)),
            isOpenEditorsPanelPresented: isOpenEditorsPanelPresented,
            isOutlinePanelPresented: isOutlinePanelPresented,
            isReferencePanelPresented: isReferencePanelPresented,
            isWorkspaceSearchPresented: isWorkspaceSearchPresented,
            isWorkspaceSymbolSearchPresented: isWorkspaceSymbolSearchPresented,
            isCallHierarchyPresented: isCallHierarchyPresented,
            problemDiagnostics: problemDiagnostics,
            semanticProblems: semanticProblems,
            selectedProblemDiagnostic: selectedProblemDiagnostic,
            isProblemsPanelPresented: isProblemsPanelPresented,
            workspaceSearchQuery: workspaceSearchQuery,
            workspaceSearchResults: workspaceSearchResults,
            workspaceSearchSummary: workspaceSearchSummary,
            workspaceSearchErrorMessage: workspaceSearchErrorMessage,
            workspaceSearchCollapsedFilePaths: Array(workspaceSearchCollapsedFilePaths).sorted(),
            selectedWorkspaceSearchMatchID: selectedWorkspaceSearchMatchID
        )
    }

    public var hasActiveHover: Bool {
        mouseHoverContent?.isEmpty == false || mouseHoverSymbolRect != .zero
    }

    public var visibleBottomPanels: [EditorBottomPanelKind] {
        var panels: [EditorBottomPanelKind] = []
        if isProblemsPanelPresented { panels.append(.problems) }
        if isReferencePanelPresented { panels.append(.references) }
        if isWorkspaceSearchPresented { panels.append(.searchResults) }
        if isWorkspaceSymbolSearchPresented { panels.append(.workspaceSymbols) }
        if isCallHierarchyPresented { panels.append(.callHierarchy) }
        return panels
    }

    public var activeBottomPanel: EditorBottomPanelKind? {
        visibleBottomPanels.last
    }

    // MARK: - 便捷方法

    /// 设置鼠标悬停状态
    func setMouseHover(content: String, symbolRect: CGRect, hoverRange: LSPRange? = nil) {
        let currentContent = mouseHoverContent ?? ""
        let currentRect = mouseHoverSymbolRect
        let epsilon: CGFloat = 0.75
        let isSameContent = currentContent == content
        let isCloseRect = abs(currentRect.minX - symbolRect.minX) <= epsilon &&
            abs(currentRect.minY - symbolRect.minY) <= epsilon &&
            abs(currentRect.width - symbolRect.width) <= epsilon &&
            abs(currentRect.height - symbolRect.height) <= epsilon
        if isSameContent && isCloseRect && mouseHoverRange == hoverRange { return }

        mouseHoverContent = content
        mouseHoverSymbolRect = symbolRect
        mouseHoverRange = hoverRange
    }

    /// 清除鼠标悬停状态
    func clearMouseHover() {
        guard mouseHoverContent != nil || mouseHoverSymbolRect != .zero || mouseHoverRange != nil else { return }
        mouseHoverContent = nil
        mouseHoverSymbolRect = .zero
        mouseHoverRange = nil
    }

    func apply(_ snapshot: EditorPanelSnapshot) {
        isOpenEditorsPanelPresented = snapshot.isOpenEditorsPanelPresented
        isOutlinePanelPresented = snapshot.isOutlinePanelPresented
        isProblemsPanelPresented = snapshot.isProblemsPanelPresented
        isReferencePanelPresented = snapshot.isReferencePanelPresented
        isWorkspaceSearchPresented = snapshot.isWorkspaceSearchPresented
        isWorkspaceSymbolSearchPresented = snapshot.isWorkspaceSymbolSearchPresented
        isCallHierarchyPresented = snapshot.isCallHierarchyPresented
    }

    func apply(_ command: EditorPanelCommand) {
        apply(EditorPanelCommandController.apply(command, to: snapshot))
    }

    func restore(from state: EditorPanelSessionState) {
        problemDiagnostics = state.problemDiagnostics
        semanticProblems = state.semanticProblems
        selectedProblemDiagnostic = state.selectedProblemDiagnostic
        referenceResults = state.referenceResults.map(Self.editorReferenceResult(from:))
        selectedReferenceResult = state.selectedReferenceResult.map(Self.editorReferenceResult(from:))
        workspaceSearchQuery = state.workspaceSearchQuery
        workspaceSearchResults = state.workspaceSearchResults
        workspaceSearchSummary = state.workspaceSearchSummary
        workspaceSearchErrorMessage = state.workspaceSearchErrorMessage
        workspaceSearchCollapsedFilePaths = Set(state.workspaceSearchCollapsedFilePaths)
        selectedWorkspaceSearchMatchID = state.selectedWorkspaceSearchMatchID
        isWorkspaceSearchLoading = false
        if let content = state.mouseHoverContent {
            setMouseHover(content: content, symbolRect: state.mouseHoverSymbolRect)
        } else {
            clearMouseHover()
        }
        isOpenEditorsPanelPresented = state.isOpenEditorsPanelPresented
        isOutlinePanelPresented = state.isOutlinePanelPresented
        isReferencePanelPresented = state.isReferencePanelPresented
        isWorkspaceSearchPresented = state.isWorkspaceSearchPresented
        isWorkspaceSymbolSearchPresented = state.isWorkspaceSymbolSearchPresented
        isCallHierarchyPresented = state.isCallHierarchyPresented
        isProblemsPanelPresented = state.isProblemsPanelPresented
    }

    // MARK: - 重置

    func reset() {
        problemDiagnostics = []
        semanticProblems = []
        selectedProblemDiagnostic = nil
        isOpenEditorsPanelPresented = false
        isOutlinePanelPresented = false
        isProblemsPanelPresented = false
        referenceResults = []
        selectedReferenceResult = nil
        isReferencePanelPresented = false
        workspaceSearchQuery = ""
        workspaceSearchResults = []
        workspaceSearchSummary = nil
        workspaceSearchErrorMessage = nil
        workspaceSearchCollapsedFilePaths = []
        selectedWorkspaceSearchMatchID = nil
        isWorkspaceSearchLoading = false
        isWorkspaceSearchPresented = false
        isWorkspaceSymbolSearchPresented = false
        isCallHierarchyPresented = false
        mouseHoverContent = nil
        mouseHoverSymbolRect = .zero
        mouseHoverRange = nil
    }

    private static func editorReferenceResult(from result: ReferenceResult) -> EditorReferenceResult {
        EditorReferenceResult(
            url: result.url,
            line: result.line,
            column: result.column,
            path: result.path,
            preview: result.preview
        )
    }

    private static func referenceResult(from result: EditorReferenceResult) -> ReferenceResult {
        ReferenceResult(
            url: result.url,
            line: result.line,
            column: result.column,
            path: result.path,
            preview: result.preview
        )
    }
}
