import Foundation
import EditorKernelCore

enum EditorOpenItemCommandController {
    static func resolve(
        _ command: EditorOpenItemCommand
    ) -> ResolvedEditorOpenItemCommand? {
        guard let kernelCommand = command.kernelValue,
              let resolved = EditorKernelCore.EditorOpenItemCommandController.resolve(kernelCommand) else {
            return nil
        }
        return .init(kernelValue: resolved)
    }
}
