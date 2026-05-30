import Combine
import EditorService
import Foundation

/// Runtime hooks supplied by the host app for package-isolated preview views.
@MainActor
public enum EditorPreviewRuntimeBridge {
    public static var editorServiceProvider: (() -> EditorService?)?
    public static var addToChatHandler: ((String) -> Void)?

    static func previewViewModel() -> EditorPreviewViewModel {
        EditorPreviewViewModelStore.shared.viewModel(for: editorServiceProvider?())
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

/// Shared automation state for Inline Preview tests.
@MainActor
public final class InlinePreviewAutomationState: ObservableObject {
    public static let shared = InlinePreviewAutomationState()

    @Published public var sessionAction: SessionAction?
    @Published public var pendingFileURL: URL?
    @Published public var lastSessionActionName: String?
    @Published public var editorPanelActivationCount: Int = 0
    @Published public var inlinePreviewTabActivationCount: Int = 0
    @Published public var demoFrameRequestCount: Int = 0
    @Published public var lastDemoFramePayload: [String: Any] = [:]
    @Published public var previewSessionStatus: String = ""
    @Published public var previewEntryStatus: String = ""
    @Published public var previewModeName: String = ""
    @Published public var previewActiveFilePath: String = ""
    @Published public var previewHasSource: Bool = false
    @Published public var previewAvailablePreviewCount: Int = 0
    @Published public var previewSelectedIndex: Int = 0
    @Published public var previewHasCurrentFrame: Bool = false
    @Published public var previewReceivedFrameCount: UInt64 = 0
    @Published public var previewLastFrameSeq: UInt64 = 0
    @Published public var previewLastBuildTitle: String = ""
    @Published public var previewLastBuildPreviewCount: Int = 0
    @Published public var previewLastBuildUsedCache: Bool = false
    @Published public var previewEntryDebugState: String = ""
    @Published public var previewLastBuildLogPath: String = ""

    private init() {}

    public enum SessionAction {
        case start
        case stop
    }
}
