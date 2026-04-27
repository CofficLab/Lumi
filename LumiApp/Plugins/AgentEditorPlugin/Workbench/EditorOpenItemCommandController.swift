import Foundation
import CodeEditSourceEditor
import LanguageServerProtocol

enum EditorOpenItemCommandController {
    static func resolve(
        _ command: EditorOpenItemCommand
    ) -> ResolvedEditorOpenItemCommand? {
        switch command {
        case let .problem(diagnostic):
            return ResolvedEditorOpenItemCommand(
                navigationRequest: nil,
                cursorPositions: EditorNavigationController.cursorPositions(for: diagnostic),
                selectedProblemDiagnostic: diagnostic,
                closeWorkspaceSymbolSearch: false
            )

        case let .reference(reference):
            return ResolvedEditorOpenItemCommand(
                navigationRequest: .reference(reference),
                cursorPositions: [],
                selectedProblemDiagnostic: nil,
                closeWorkspaceSymbolSearch: false
            )

        case let .workspaceSymbol(symbol):
            guard let url = URL(string: symbol.location.uri), url.isFileURL else {
                return nil
            }

            let start = symbol.location.range.start
            return ResolvedEditorOpenItemCommand(
                navigationRequest: .workspaceSymbol(
                    url,
                    CursorPosition(
                        start: .init(
                            line: Int(start.line) + 1,
                            column: Int(start.character) + 1
                        ),
                        end: nil
                    )
                ),
                cursorPositions: [],
                selectedProblemDiagnostic: nil,
                closeWorkspaceSymbolSearch: true
            )

        case let .callHierarchyItem(item):
            guard let url = URL(string: item.uri), url.isFileURL else {
                return nil
            }

            let start = item.selectionRange.start
            return ResolvedEditorOpenItemCommand(
                navigationRequest: .callHierarchyItem(
                    url,
                    CursorPosition(
                        start: .init(
                            line: Int(start.line) + 1,
                            column: Int(start.character) + 1
                        ),
                        end: nil
                    )
                ),
                cursorPositions: [],
                selectedProblemDiagnostic: nil,
                closeWorkspaceSymbolSearch: false
            )
        }
    }
}
