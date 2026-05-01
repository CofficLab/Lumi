import Foundation

struct EditorTab: Identifiable, Equatable {
    let sessionID: EditorSession.ID
    var fileURL: URL?
    var title: String
    var isDirty: Bool
    var isPinned: Bool
    var isPreview: Bool

    var id: EditorSession.ID { sessionID }

    init(
        sessionID: EditorSession.ID,
        fileURL: URL?,
        title: String? = nil,
        isDirty: Bool = false,
        isPinned: Bool = false,
        isPreview: Bool = false
    ) {
        self.sessionID = sessionID
        self.fileURL = fileURL
        self.title = title ?? fileURL?.lastPathComponent ?? "Untitled"
        self.isDirty = isDirty
        self.isPinned = isPinned
        self.isPreview = isPreview
    }
}
