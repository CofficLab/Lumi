import AppKit
import Foundation

@MainActor
public final class EditorFileService {
    private let state: EditorState

    init(state: EditorState) {
        self.state = state
    }

    public var currentFileURL: URL? { state.currentFileURL }
    public var isFileLoadInProgress: Bool { state.isFileLoadInProgress }
    public var fileLoadErrorMessage: String? { state.fileLoadErrorMessage }
    public var fileName: String { state.fileName }
    public var fileExtension: String { state.fileExtension }
    public var content: NSTextStorage? { state.content }
    public var contentRevision: UInt64 { state.contentRevision }
    public var saveRevision: UInt64 { state.saveRevision }
    public var relativeFilePath: String { state.relativeFilePath }
    public var isEditable: Bool { state.isEditable }
    public var isTruncated: Bool { state.isTruncated }
    public var isBinaryFile: Bool { state.isBinaryFile }
    public var isMarkdownFile: Bool { state.isMarkdownFile }
    public var hasUnsavedChanges: Bool { state.hasUnsavedChanges }
    public var canPreview: Bool { state.canPreview }
    public var largeFileMode: LargeFileMode { state.largeFileMode }
    public var canLoadFullFile: Bool { state.canLoadFullFile }
    var saveState: EditorSaveState { state.saveState }

    public func saveNow() {
        state.saveNow()
    }

    @discardableResult
    public func replaceCurrentDocumentText(_ text: String, reason: String) -> Bool {
        state.applyFullTextEdit(
            replacementText: text,
            selectedRanges: [NSRange(location: 0, length: 0)],
            reason: reason
        )
    }

    public func loadFile(from url: URL?) {
        state.loadFile(from: url)
    }

    public func applySessionRestore(_ session: EditorSession) {
        state.applySessionRestore(session)
    }

    public func loadFullFile() {
        state.loadFullFileFromDisk()
    }
}
