import EditorKernel
import Foundation
import CodeEditSourceEditor

public enum EditorNavigationRequest: Equatable {
    case reference(ReferenceResult)
    case workspaceSymbol(URL, CursorPosition)
    case callHierarchyItem(URL, CursorPosition)
    case definition(URL, CursorPosition, highlightLine: Bool)
}

struct ResolvedEditorNavigationRequest: Equatable {
    let url: URL
    let target: CursorPosition
    let highlightLine: Bool
}

extension EditorNavigationRequest {
    var kernelValue: EditorKernel.EditorNavigationRequest {
        switch self {
        case let .reference(reference):
            return .reference(reference)
        case let .workspaceSymbol(url, target):
            return .workspaceSymbol(url, target.kernelValue)
        case let .callHierarchyItem(url, target):
            return .callHierarchyItem(url, target.kernelValue)
        case let .definition(url, target, highlightLine):
            return .definition(url, target.kernelValue, highlightLine: highlightLine)
        }
    }
}

extension ResolvedEditorNavigationRequest {
    init(kernelValue: EditorKernel.ResolvedEditorNavigationRequest) {
        self.url = kernelValue.url
        self.target = .init(kernelValue: kernelValue.target)
        self.highlightLine = kernelValue.highlightLine
    }
}
