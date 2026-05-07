import EditorKernelCore
import CodeEditSourceEditor
import LanguageServerProtocol

enum EditorNavigationController {
    static func resolve(
        _ request: EditorNavigationRequest
    ) -> ResolvedEditorNavigationRequest {
        .init(kernelValue: EditorKernelCore.EditorNavigationController.resolve(request.kernelValue))
    }

    static func cursorPositions(for diagnostic: Diagnostic) -> [CursorPosition] {
        EditorKernelCore.EditorNavigationController
            .cursorPositions(for: diagnostic)
            .map(CursorPosition.init(kernelValue:))
    }

    static func resolvedDefinitionTarget(
        from target: CursorPosition,
        highlightLine: Bool,
        content: String?
    ) -> CursorPosition {
        .init(
            kernelValue: EditorKernelCore.EditorNavigationController.resolvedDefinitionTarget(
                from: target.kernelValue,
                highlightLine: highlightLine,
                content: content
            )
        )
    }
}

private extension CursorPosition {
    var kernelValue: EditorKernelCore.EditorCursorPosition {
        .init(start: .init(line: start.line, column: start.column), end: end.map {
            .init(line: $0.line, column: $0.column)
        })
    }

    init(kernelValue: EditorKernelCore.EditorCursorPosition) {
        self.init(
            start: .init(line: kernelValue.start.line, column: kernelValue.start.column),
            end: kernelValue.end.map { .init(line: $0.line, column: $0.column) }
        )
    }
}
