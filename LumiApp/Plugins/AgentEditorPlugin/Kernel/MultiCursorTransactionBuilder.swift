import Foundation

enum MultiCursorTransactionBuilder {
    static func makeTransaction(
        operation: MultiCursorOperation,
        selections: [MultiCursorSelection],
        updatedSelections: [MultiCursorSelection]
    ) -> EditorTransaction {
        let replacements: [EditorTransaction.Replacement]

        switch operation {
        case .replaceSelection(let replacementText):
            replacements = selections.map {
                EditorTransaction.Replacement(
                    range: EditorRange(location: $0.location, length: $0.length),
                    text: replacementText
                )
            }
        case .insert(let insertedText):
            replacements = selections.map {
                EditorTransaction.Replacement(
                    range: EditorRange(location: $0.location, length: $0.length),
                    text: insertedText
                )
            }
        case .deleteBackward:
            replacements = selections.map { selection in
                if selection.length > 0 {
                    return EditorTransaction.Replacement(
                        range: EditorRange(location: selection.location, length: selection.length),
                        text: ""
                    )
                }

                let deleteLocation = max(selection.location - 1, 0)
                let deleteLength = selection.location > 0 ? 1 : 0
                return EditorTransaction.Replacement(
                    range: EditorRange(location: deleteLocation, length: deleteLength),
                    text: ""
                )
            }
        }

        return EditorTransaction(
            replacements: replacements,
            updatedSelections: updatedSelections.map {
                EditorSelection(
                    range: EditorRange(location: $0.location, length: $0.length)
                )
            }
        )
    }
}
