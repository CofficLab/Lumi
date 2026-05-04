import Foundation

struct EditorOpenEditorItem: Identifiable, Equatable {
    let sessionID: EditorSession.ID
    let fileURL: URL?
    let title: String
    let isDirty: Bool
    let isPinned: Bool
    let isActive: Bool
    let recentActivationRank: Int?

    var id: EditorSession.ID { sessionID }
}
