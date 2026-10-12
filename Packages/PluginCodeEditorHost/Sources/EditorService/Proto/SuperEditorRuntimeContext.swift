import Foundation

@MainActor
public final class SuperEditorRuntimeContext {
    public static let shared = SuperEditorRuntimeContext()

    public private(set) var currentFileURL: URL?
    public private(set) var currentContent: String = ""

    private init() {}

    public func updateCurrentDocument(fileURL: URL?, content: String?) {
        currentFileURL = fileURL
        currentContent = content ?? ""
    }
}
