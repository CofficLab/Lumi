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

    var snapshot: EditorPanelSnapshot {
        EditorPanelSnapshot(
            isProblemsPanelPresented: isProblemsPanelPresented,
            isReferencePanelPresented: isReferencePanelPresented,
            isWorkspaceSymbolSearchPresented: isWorkspaceSymbolSearchPresented,
            isCallHierarchyPresented: isCallHierarchyPresented
        )
    }

    var sessionState: EditorPanelSessionState {
        EditorPanelSessionState(
            mouseHoverContent: mouseHoverContent,
            mouseHoverSymbolRect: mouseHoverSymbolRect,
            referenceResults: referenceResults.map(Self.referenceResult(from:)),
            isReferencePanelPresented: isReferencePanelPresented,
            isWorkspaceSymbolSearchPresented: isWorkspaceSymbolSearchPresented,
            isCallHierarchyPresented: isCallHierarchyPresented,
            problemDiagnostics: problemDiagnostics,
            selectedProblemDiagnostic: selectedProblemDiagnostic,
            isProblemsPanelPresented: isProblemsPanelPresented
        )
    }

    var hasActiveHover: Bool {
        mouseHoverContent?.isEmpty == false || mouseHoverSymbolRect != .zero
    }

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

    func apply(_ snapshot: EditorPanelSnapshot) {
        isProblemsPanelPresented = snapshot.isProblemsPanelPresented
        isReferencePanelPresented = snapshot.isReferencePanelPresented
        isWorkspaceSymbolSearchPresented = snapshot.isWorkspaceSymbolSearchPresented
        isCallHierarchyPresented = snapshot.isCallHierarchyPresented
    }

    func apply(_ command: EditorPanelCommand) {
        apply(EditorPanelCommandController.apply(command, to: snapshot))
    }

    func restore(from state: EditorPanelSessionState) {
        problemDiagnostics = state.problemDiagnostics
        selectedProblemDiagnostic = state.selectedProblemDiagnostic
        referenceResults = state.referenceResults.map(Self.editorReferenceResult(from:))
        if let content = state.mouseHoverContent {
            setMouseHover(content: content, symbolRect: state.mouseHoverSymbolRect)
        } else {
            clearMouseHover()
        }
        isReferencePanelPresented = state.isReferencePanelPresented
        isWorkspaceSymbolSearchPresented = state.isWorkspaceSymbolSearchPresented
        isCallHierarchyPresented = state.isCallHierarchyPresented
        isProblemsPanelPresented = state.isProblemsPanelPresented
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

/// LSP 引用查询结果
struct EditorReferenceResult: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let line: Int
    let column: Int
    let path: String
    let preview: String
}

struct EditorPanelSessionState: Equatable {
    let mouseHoverContent: String?
    let mouseHoverSymbolRect: CGRect
    let referenceResults: [ReferenceResult]
    let isReferencePanelPresented: Bool
    let isWorkspaceSymbolSearchPresented: Bool
    let isCallHierarchyPresented: Bool
    let problemDiagnostics: [Diagnostic]
    let selectedProblemDiagnostic: Diagnostic?
    let isProblemsPanelPresented: Bool

    var snapshot: EditorPanelSnapshot {
        EditorPanelSnapshot(
            isProblemsPanelPresented: isProblemsPanelPresented,
            isReferencePanelPresented: isReferencePanelPresented,
            isWorkspaceSymbolSearchPresented: isWorkspaceSymbolSearchPresented,
            isCallHierarchyPresented: isCallHierarchyPresented
        )
    }

    init(
        mouseHoverContent: String? = nil,
        mouseHoverSymbolRect: CGRect = .zero,
        referenceResults: [ReferenceResult] = [],
        isReferencePanelPresented: Bool = false,
        isWorkspaceSymbolSearchPresented: Bool = false,
        isCallHierarchyPresented: Bool = false,
        problemDiagnostics: [Diagnostic] = [],
        selectedProblemDiagnostic: Diagnostic? = nil,
        isProblemsPanelPresented: Bool = false
    ) {
        self.mouseHoverContent = mouseHoverContent
        self.mouseHoverSymbolRect = mouseHoverSymbolRect
        self.referenceResults = referenceResults
        self.isReferencePanelPresented = isReferencePanelPresented
        self.isWorkspaceSymbolSearchPresented = isWorkspaceSymbolSearchPresented
        self.isCallHierarchyPresented = isCallHierarchyPresented
        self.problemDiagnostics = problemDiagnostics
        self.selectedProblemDiagnostic = selectedProblemDiagnostic
        self.isProblemsPanelPresented = isProblemsPanelPresented
    }

    @MainActor
    init(session: EditorSession) {
        self = session.panelState
    }
}
