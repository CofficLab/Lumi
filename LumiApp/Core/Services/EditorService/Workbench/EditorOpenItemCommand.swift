import Foundation
import CodeEditSourceEditor
import LanguageServerProtocol
import EditorKernelCore

enum EditorOpenItemCommand: Equatable {
    case problem(Diagnostic)
    case reference(ReferenceResult)
    case workspaceSymbol(WorkspaceSymbolItem)
    case callHierarchyItem(EditorCallHierarchyItem)
    case documentSymbol(EditorDocumentSymbolItem)
}

struct ResolvedEditorOpenItemCommand: Equatable {
    let navigationRequest: EditorNavigationRequest?
    let cursorPositions: [CursorPosition]
    let selectedProblemDiagnostic: Diagnostic?
    let selectedReferenceResult: ReferenceResult?
    let presentBottomPanel: EditorBottomPanelKind?
    let closeWorkspaceSymbolSearch: Bool
}

extension EditorOpenItemCommand {
    var kernelValue: EditorKernelCore.EditorOpenItemCommand? {
        switch self {
        case let .problem(diagnostic):
            return .problem(diagnostic)
        case let .reference(reference):
            return .reference(reference)
        case let .workspaceSymbol(symbol):
            return .workspaceSymbol(
                .init(
                    uri: symbol.location.uri,
                    line: Int(symbol.location.range.start.line),
                    character: Int(symbol.location.range.start.character)
                )
            )
        case let .callHierarchyItem(item):
            guard let url = URL(string: item.uri), url.isFileURL else { return nil }
            let start = item.selectionRange.start
            return .callHierarchyItem(
                url,
                .init(
                    start: .init(line: Int(start.line) + 1, column: Int(start.character) + 1),
                    end: nil
                )
            )
        case let .documentSymbol(item):
            return .documentSymbol(item)
        }
    }
}

extension ResolvedEditorOpenItemCommand {
    init(kernelValue: EditorKernelCore.ResolvedEditorOpenItemCommand) {
        self.navigationRequest = kernelValue.navigationRequest.map {
            switch $0 {
            case let .reference(reference):
                return .reference(reference)
            case let .workspaceSymbol(url, target):
                return .workspaceSymbol(url, .init(kernelValue: target))
            case let .callHierarchyItem(url, target):
                return .callHierarchyItem(url, .init(kernelValue: target))
            case let .definition(url, target, highlightLine):
                return .definition(url, .init(kernelValue: target), highlightLine: highlightLine)
            }
        }
        self.cursorPositions = kernelValue.cursorPositions.map(CursorPosition.init(kernelValue:))
        self.selectedProblemDiagnostic = kernelValue.selectedProblemDiagnostic
        self.selectedReferenceResult = kernelValue.selectedReferenceResult
        self.presentBottomPanel = kernelValue.presentBottomPanel
        self.closeWorkspaceSymbolSearch = kernelValue.closeWorkspaceSymbolSearch
    }
}

private extension CursorPosition {
    init(kernelValue: EditorKernelCore.EditorCursorPosition) {
        self.init(
            start: .init(line: kernelValue.start.line, column: kernelValue.start.column),
            end: kernelValue.end.map { .init(line: $0.line, column: $0.column) }
        )
    }
}
