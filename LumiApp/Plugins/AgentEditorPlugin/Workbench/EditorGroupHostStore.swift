import Foundation

@MainActor
final class EditorGroupHostStore: ObservableObject {
    private var states: [EditorGroup.ID: EditorState] = [:]

    func state(for groupID: EditorGroup.ID) -> EditorState {
        if let existing = states[groupID] {
            return existing
        }

        let created = EditorState()
        states[groupID] = created
        return created
    }

    func removeState(for groupID: EditorGroup.ID) {
        states.removeValue(forKey: groupID)
    }

    func retainOnly(_ groupIDs: Set<EditorGroup.ID>) {
        states = states.filter { groupIDs.contains($0.key) }
    }
}
