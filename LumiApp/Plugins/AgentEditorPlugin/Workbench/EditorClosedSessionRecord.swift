import Foundation

struct EditorClosedSessionRecord {
    let snapshot: EditorSession
    let tab: EditorTab
    let preferredGroupID: EditorGroup.ID?

    var sessionID: EditorSession.ID { snapshot.id }
    var fileURL: URL? { snapshot.fileURL ?? tab.fileURL }
}
