import Foundation

public struct EditorSnapshot: Equatable, Sendable {
    public let text: String
    public let version: Int

    public init(text: String, version: Int) {
        self.text = text
        self.version = version
    }
}

public struct EditorEditResult: Equatable, Sendable {
    public let snapshot: EditorSnapshot
    public let selections: [EditorSelection]?

    public init(snapshot: EditorSnapshot, selections: [EditorSelection]?) {
        self.snapshot = snapshot
        self.selections = selections
    }
}

public final class EditorBuffer {
    public private(set) var text: String
    public private(set) var version: Int

    public init(text: String, version: Int = 0) {
        self.text = text
        self.version = version
    }

    public func snapshot() -> EditorSnapshot {
        EditorSnapshot(text: text, version: version)
    }

    @discardableResult
    public func replaceText(_ newText: String) -> EditorEditResult {
        text = newText
        version += 1
        return EditorEditResult(snapshot: snapshot(), selections: nil)
    }

    @discardableResult
    public func apply(_ transaction: EditorTransaction) -> EditorEditResult? {
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
