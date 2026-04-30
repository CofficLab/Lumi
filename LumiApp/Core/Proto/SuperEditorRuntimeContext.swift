import Foundation

@MainActor
final class SuperEditorRuntimeContext {
    static let shared = SuperEditorRuntimeContext()

    private(set) var currentFileURL: URL?
    private(set) var currentContent: String = ""

    private init() {}

    func updateCurrentDocument(fileURL: URL?, content: String?) {
        currentFileURL = fileURL
        currentContent = content ?? ""
    }
}
