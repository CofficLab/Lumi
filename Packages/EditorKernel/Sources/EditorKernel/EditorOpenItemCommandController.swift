import Foundation
import LanguageServerProtocol

public enum EditorOpenItemCommandController {
    public static func resolve(
        _ command: EditorOpenItemCommand
    ) -> ResolvedEditorOpenItemCommand? {
        switch command {
        case let .problem(diagnostic):
            return ResolvedEditorOpenItemCommand(
                navigationRequest: nil,
                cursorPositions: EditorNavigationController.cursorPositions(for: diagnostic),
                selectedProblemDiagnostic: diagnostic,
                selectedReferenceResult: nil,
                presentBottomPanel: .problems,
                closeWorkspaceSymbolSearch: false
            )

        case let .reference(reference):
            return ResolvedEditorOpenItemCommand(
                navigationRequest: .reference(reference),
                cursorPositions: [],
                selectedProblemDiagnostic: nil,
                selectedReferenceResult: reference,
                presentBottomPanel: .references,
                closeWorkspaceSymbolSearch: false
            )

        case let .workspaceSymbol(symbol):
            guard let url = URL(string: symbol.uri), url.isFileURL else {
                return nil
            }

            return ResolvedEditorOpenItemCommand(
                navigationRequest: .workspaceSymbol(
                    url,
                    EditorCursorPosition(
                        start: .init(
                            line: symbol.line + 1,
                            column: symbol.character + 1
                        ),
                        end: nil
                    )
                ),
                cursorPositions: [],
                selectedProblemDiagnostic: nil,
                selectedReferenceResult: nil,
                presentBottomPanel: nil,
                closeWorkspaceSymbolSearch: true
            )

        case let .callHierarchyItem(url, cursorPosition):
            return ResolvedEditorOpenItemCommand(
                navigationRequest: .callHierarchyItem(url, cursorPosition),
                cursorPositions: [],
                selectedProblemDiagnostic: nil,
                selectedReferenceResult: nil,
                presentBottomPanel: nil,
                closeWorkspaceSymbolSearch: false
            )

        case let .documentSymbol(item):
            return ResolvedEditorOpenItemCommand(
                navigationRequest: nil,
                cursorPositions: [
                    EditorCursorPosition(
                        start: .init(line: item.line, column: item.column),
                        end: nil
                    )
                ],
                selectedProblemDiagnostic: nil,
                selectedReferenceResult: nil,
                presentBottomPanel: nil,
                closeWorkspaceSymbolSearch: false
            )
        }
    }
}
