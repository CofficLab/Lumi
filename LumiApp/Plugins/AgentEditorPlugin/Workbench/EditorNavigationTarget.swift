import Foundation

struct EditorNavigationTarget: Equatable {
    let sessionID: EditorSession.ID
    let fileURL: URL?
    let title: String
    let isDirty: Bool
    let isPinned: Bool
}
