import Foundation
import EditorKernel

enum EditorOpenItemCommandController {
    static func resolve(
        _ command: EditorOpenItemCommand
    ) -> ResolvedEditorOpenItemCommand? {
        guard let kernelCommand = command.kernelValue,
              let resolved = EditorKernel.EditorOpenItemCommandController.resolve(kernelCommand) else {
            return nil
        }
        return .init(kernelValue: resolved)
    }
}
