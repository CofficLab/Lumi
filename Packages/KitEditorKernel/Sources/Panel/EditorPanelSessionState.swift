import CoreGraphics
import Foundation
import LanguageServerProtocol

public struct EditorPanelSessionState: Equatable {
    public let mouseHoverContent: String?
    public let mouseHoverSymbolRect: CGRect
    public let referenceResults: [ReferenceResult]
    public let selectedReferenceResult: ReferenceResult?
    public let isOpenEditorsPanelPresented: Bool
    public let isOutlinePanelPresented: Bool
    public let isReferencePanelPresented: Bool
    public let isWorkspaceSearchPresented: Bool
    public let isWorkspaceSymbolSearchPresented: Bool
    public let isCallHierarchyPresented: Bool
    public let problemDiagnostics: [Diagnostic]
    public let semanticProblems: [EditorSemanticProblem]
    public let selectedProblemDiagnostic: Diagnostic?
    public let isProblemsPanelPresented: Bool
    public let workspaceSearchQuery: String
    public let workspaceSearchResults: [EditorWorkspaceSearchFileResult]
    public let workspaceSearchSummary: EditorWorkspaceSearchSummary?
    public let workspaceSearchErrorMessage: String?
    public let workspaceSearchCollapsedFilePaths: [String]
    public let selectedWorkspaceSearchMatchID: String?

    public var snapshot: EditorPanelSnapshot {
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

    public init(
        mouseHoverContent: String? = nil,
        mouseHoverSymbolRect: CGRect = .zero,
        referenceResults: [ReferenceResult] = [],
        selectedReferenceResult: ReferenceResult? = nil,
        isOpenEditorsPanelPresented: Bool = false,
        isOutlinePanelPresented: Bool = false,
        isReferencePanelPresented: Bool = false,
        isWorkspaceSearchPresented: Bool = false,
        isWorkspaceSymbolSearchPresented: Bool = false,
        isCallHierarchyPresented: Bool = false,
        problemDiagnostics: [Diagnostic] = [],
        semanticProblems: [EditorSemanticProblem] = [],
        selectedProblemDiagnostic: Diagnostic? = nil,
        isProblemsPanelPresented: Bool = false,
        workspaceSearchQuery: String = "",
        workspaceSearchResults: [EditorWorkspaceSearchFileResult] = [],
        workspaceSearchSummary: EditorWorkspaceSearchSummary? = nil,
        workspaceSearchErrorMessage: String? = nil,
        workspaceSearchCollapsedFilePaths: [String] = [],
        selectedWorkspaceSearchMatchID: String? = nil
    ) {
        self.mouseHoverContent = mouseHoverContent
        self.mouseHoverSymbolRect = mouseHoverSymbolRect
        self.referenceResults = referenceResults
        self.selectedReferenceResult = selectedReferenceResult
        self.isOpenEditorsPanelPresented = isOpenEditorsPanelPresented
        self.isOutlinePanelPresented = isOutlinePanelPresented
        self.isReferencePanelPresented = isReferencePanelPresented
        self.isWorkspaceSearchPresented = isWorkspaceSearchPresented
        self.isWorkspaceSymbolSearchPresented = isWorkspaceSymbolSearchPresented
        self.isCallHierarchyPresented = isCallHierarchyPresented
        self.problemDiagnostics = problemDiagnostics
        self.semanticProblems = semanticProblems
        self.selectedProblemDiagnostic = selectedProblemDiagnostic
        self.isProblemsPanelPresented = isProblemsPanelPresented
        self.workspaceSearchQuery = workspaceSearchQuery
        self.workspaceSearchResults = workspaceSearchResults
        self.workspaceSearchSummary = workspaceSearchSummary
        self.workspaceSearchErrorMessage = workspaceSearchErrorMessage
        self.workspaceSearchCollapsedFilePaths = workspaceSearchCollapsedFilePaths
        self.selectedWorkspaceSearchMatchID = selectedWorkspaceSearchMatchID
    }
}
