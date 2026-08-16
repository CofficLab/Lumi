import Foundation
import KernelLumi

/// Runtime hooks supplied by the host app for package-isolated preview views.
@MainActor
public enum EditorPreviewRuntimeBridge {
    nonisolated(unsafe) public static var kernel: KernelLumi?
    public static var addToChatHandler: ((String) -> Void)?

    static func previewViewModel(for editorV2: (any EditorProvidingV2)?) -> EditorPreviewViewModel {
        EditorPreviewViewModelStore.shared.viewModel(for: editorV2)
    }
}

@MainActor
final class EditorPreviewViewModelStore {
    static let shared = EditorPreviewViewModelStore()

    private var viewModelsByEditorV2: [ObjectIdentifier: EditorPreviewViewModel] = [:]
    private var fallbackViewModel: EditorPreviewViewModel?

    private init() {}

    func viewModel(for editorV2: (any EditorProvidingV2)?) -> EditorPreviewViewModel {
        guard let editorV2 else {
            if let fallbackViewModel {
                return fallbackViewModel
            }
            let viewModel = EditorPreviewViewModel()
            fallbackViewModel = viewModel
            return viewModel
        }

        let key = ObjectIdentifier(editorV2)
        if let viewModel = viewModelsByEditorV2[key] {
            return viewModel
        }

        let viewModel = EditorPreviewViewModel()
        viewModel.wireEditorV2(editorV2)
        viewModelsByEditorV2[key] = viewModel
        return viewModel
    }

    func resetForTesting() {
        viewModelsByEditorV2.removeAll()
        fallbackViewModel = nil
    }
}
