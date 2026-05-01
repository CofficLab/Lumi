import Foundation

struct EditorSnapshot: Equatable, Sendable {
    let text: String
    let version: Int
}

struct EditorEditResult: Equatable, Sendable {
    let snapshot: EditorSnapshot
    let selections: [EditorSelection]?
}

final class EditorBuffer {
    private(set) var text: String
    private(set) var version: Int

    init(text: String, version: Int = 0) {
        self.text = text
        self.version = version
    }

    func snapshot() -> EditorSnapshot {
        EditorSnapshot(text: text, version: version)
    }

    @discardableResult
    func replaceText(_ newText: String) -> EditorEditResult {
        text = newText
        version += 1
        return EditorEditResult(snapshot: snapshot(), selections: nil)
    }

    @discardableResult
    func apply(_ transaction: EditorTransaction) -> EditorEditResult? {
        guard !transaction.replacements.isEmpty else {
            return EditorEditResult(snapshot: snapshot(), selections: transaction.updatedSelections)
        }

        var updated = text
        let sorted = transaction.replacements.sorted { lhs, rhs in
            if lhs.range.location != rhs.range.location {
                return lhs.range.location > rhs.range.location
            }
            return lhs.range.length > rhs.range.length
        }

        for replacement in sorted {
            let nsRange = replacement.range.nsRange
            guard nsRange.location != NSNotFound,
                  nsRange.location >= 0,
                  nsRange.length >= 0,
                  NSMaxRange(nsRange) <= (updated as NSString).length,
                  let swiftRange = Range(nsRange, in: updated) else {
                return nil
            }
            updated.replaceSubrange(swiftRange, with: replacement.text)
        }

        text = updated
        version += 1
        return EditorEditResult(snapshot: snapshot(), selections: transaction.updatedSelections)
    }
}
