import EditorKernel
import EditorSource
import LanguageServerProtocol

enum EditorNavigationController {
    static func resolve(
        _ request: EditorNavigationRequest
    ) -> ResolvedEditorNavigationRequest {
        .init(kernelValue: EditorKernel.EditorNavigationController.resolve(request.kernelValue))
    }

    static func cursorPositions(for diagnostic: Diagnostic) -> [CursorPosition] {
        EditorKernel.EditorNavigationController
            .cursorPositions(for: diagnostic)
            .map(CursorPosition.init(kernelValue:))
    }

    static func resolvedDefinitionTarget(
        from target: CursorPosition,
        highlightLine: Bool,
        content: String?
    ) -> CursorPosition {
        .init(
            kernelValue: EditorKernel.EditorNavigationController.resolvedDefinitionTarget(
                from: target.kernelValue,
                highlightLine: highlightLine,
                content: content
            )
        )
    }
}

extension CursorPosition {
    var kernelValue: EditorKernel.EditorCursorPosition {
        .init(start: .init(line: start.line, column: start.column), end: end.map {
            .init(line: $0.line, column: $0.column)
        })
    }

    init(kernelValue: EditorKernel.EditorCursorPosition) {
        self.init(
            start: .init(line: kernelValue.start.line, column: kernelValue.start.column),
            end: kernelValue.end.map { .init(line: $0.line, column: $0.column) }
        )
    }
}
