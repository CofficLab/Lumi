import Foundation

@MainActor
final class XcodeProjectEditorRuntimeContext {
    static let shared = XcodeProjectEditorRuntimeContext()

    private(set) var currentFileURL: URL?
    private(set) var currentContent: String = ""

    private init() {}

    func updateCurrentDocument(fileURL: URL?, content: String?) {
        currentFileURL = fileURL
        currentContent = content ?? ""
    }
}
