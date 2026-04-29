import Foundation
import LanguageServerProtocol

struct EditorTransactionCommitPayload {
    let text: String
    let version: Int
    let totalLines: Int
    let canonicalSelectionSet: EditorSelectionSet?
    let multiCursorSelections: [MultiCursorSelection]?
}

@MainActor
final class EditorTransactionController {
    func transactionForTextEdits(
        _ edits: [TextEdit],
        in text: String,
        currentSelections: [NSRange]
    ) -> EditorTransaction? {
        guard let transaction = TextEditTransactionBuilder.makeTransaction(edits: edits, in: text) else {
            return nil
        }

        if transaction.updatedSelections == nil,
           let remappedSelections = remappedSelections(
                currentSelections: currentSelections,
                for: transaction.replacements
           ) {
            return EditorTransaction(
                replacements: transaction.replacements,
                updatedSelections: remappedSelections
            )
        }

        return transaction
    }

    func transactionForInputEdit(
        replacementRange: NSRange,
        replacementText: String,
        selectedRanges: [NSRange]
    ) -> EditorTransaction? {
        guard replacementRange.location != NSNotFound else { return nil }

        return EditorTransaction(
            replacements: [
                .init(
                    range: EditorRange(
                        location: replacementRange.location,
                        length: replacementRange.length
                    ),
                    text: replacementText
                )
            ],
            updatedSelections: selectedRanges.map {
                EditorSelection(
                    range: EditorRange(
                        location: $0.location,
                        length: $0.length
                    )
                )
            }
        )
    }

    func transactionForCompletionEdit(
        text: String,
        replacementRange: NSRange,
        replacementText: String,
        additionalTextEdits: [TextEdit]?
    ) -> EditorTransaction? {
        var replacements: [EditorTransaction.Replacement] = [
            .init(
                range: EditorRange(
                    location: replacementRange.location,
                    length: replacementRange.length
                ),
                text: replacementText
            )
        ]

        if let additionalTextEdits, !additionalTextEdits.isEmpty {
            guard let additionalTransaction = TextEditTransactionBuilder.makeTransaction(
                edits: additionalTextEdits,
                in: text
            ) else {
                return nil
            }
            replacements.append(contentsOf: additionalTransaction.replacements)
        }

        let sortedReplacements = replacements.sorted { lhs, rhs in
            if lhs.range.location != rhs.range.location {
                return lhs.range.location < rhs.range.location
            }
            return lhs.range.length < rhs.range.length
        }

        let selectionAnchor = replacementRange.location + replacementRange.length
        let finalCursorLocation = remappedOffset(
            selectionAnchor,
            isRangeEnd: true,
            replacements: sortedReplacements
        )

        return EditorTransaction(
            replacements: replacements,
            updatedSelections: [
                EditorSelection(
                    range: EditorRange(location: finalCursorLocation, length: 0)
                )
            ]
        )
    }

    func commitPayload(from result: EditorEditResult) -> EditorTransactionCommitPayload {
        let selections = result.selections
        return EditorTransactionCommitPayload(
            text: result.snapshot.text,
            version: result.snapshot.version,
            totalLines: result.snapshot.text.filter { $0 == "\n" }.count + 1,
            canonicalSelectionSet: selections.map { EditorSelectionSet(selections: $0) },
            multiCursorSelections: selections?.map {
                MultiCursorSelection(location: $0.range.location, length: $0.range.length)
            }
        )
    }

    private func remappedSelections(
        currentSelections: [NSRange],
        for replacements: [EditorTransaction.Replacement]
    ) -> [EditorSelection]? {
        guard !currentSelections.isEmpty else { return nil }

        let sortedReplacements = replacements.sorted { lhs, rhs in
            if lhs.range.location != rhs.range.location {
                return lhs.range.location < rhs.range.location
            }
            return lhs.range.length < rhs.range.length
        }

        return currentSelections.map { selection in
            let start = remappedOffset(
                selection.location,
                isRangeEnd: false,
                replacements: sortedReplacements
            )
            let end = remappedOffset(
                selection.location + selection.length,
                isRangeEnd: true,
                replacements: sortedReplacements
            )
            return EditorSelection(
                range: EditorRange(
                    location: min(start, end),
                    length: max(end - start, 0)
                )
            )
        }
    }

    private func remappedOffset(
        _ offset: Int,
        isRangeEnd: Bool,
        replacements: [EditorTransaction.Replacement]
    ) -> Int {
        var mapped = offset
        for replacement in replacements {
            let start = replacement.range.location
            let end = replacement.range.location + replacement.range.length
            let delta = (replacement.text as NSString).length - replacement.range.length

            if mapped < start {
                continue
            }

            if mapped > end || (mapped == end && isRangeEnd) {
                mapped += delta
                continue
            }

            mapped = start + (replacement.text as NSString).length
        }
        return max(mapped, 0)
    }
}
