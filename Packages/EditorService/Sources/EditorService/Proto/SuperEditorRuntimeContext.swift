import Foundation

@MainActor
public final class SuperEditorRuntimeContext {
    public static let shared = SuperEditorRuntimeContext()

    private(set) var currentFileURL: URL?
    private(set) var currentContent: String = ""

    private init() {}

    public func updateCurrentDocument(fileURL: URL?, content: String?) {
        currentFileURL = fileURL
        currentContent = content ?? ""
    }
}
