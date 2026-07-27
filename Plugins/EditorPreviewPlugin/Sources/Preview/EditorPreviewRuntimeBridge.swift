import EditorService
import Foundation
import LumiKernel

/// Runtime hooks supplied by the host app for package-isolated preview views.
@MainActor
public enum EditorPreviewRuntimeBridge {
    nonisolated(unsafe) public static var kernel: LumiKernel?
    public static var addToChatHandler: ((String) -> Void)?
    public static var editorServiceProvider: (() -> EditorService?)?

    public static var editorService: EditorService? {
        editorServiceProvider?()
    }

    static func previewViewModel() -> EditorPreviewViewModel {
        EditorPreviewViewModelStore.shared.viewModel(for: editorService)
    }
}

@MainActor
final class EditorPreviewViewModelStore {
    static let shared = EditorPreviewViewModelStore()

    private var viewModelsByEditorService: [ObjectIdentifier: EditorPreviewViewModel] = [:]
    private var fallbackViewModel: EditorPreviewViewModel?

    private init() {}

    func viewModel(for editorService: EditorService?) -> EditorPreviewViewModel {
        guard let editorService else {
            if let fallbackViewModel {
                return fallbackViewModel
            }
            let viewModel = EditorPreviewViewModel()
            fallbackViewModel = viewModel
            return viewModel
        }

        let key = ObjectIdentifier(editorService)
        if let viewModel = viewModelsByEditorService[key] {
            return viewModel
        }

        let viewModel = EditorPreviewViewModel()
        viewModel.wireEditorService(editorService)
        viewModelsByEditorService[key] = viewModel
        return viewModel
    }

    func resetForTesting() {
        viewModelsByEditorService.removeAll()
        fallbackViewModel = nil
    }
}