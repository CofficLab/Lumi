import Foundation

struct EditorRange: Equatable, Sendable {
    let location: Int
    let length: Int

    var nsRange: NSRange {
        NSRange(location: location, length: length)
    }
}

struct EditorSelection: Equatable, Sendable {
    let range: EditorRange
}

struct EditorTransaction: Equatable, Sendable {
    struct Replacement: Equatable, Sendable {
        let range: EditorRange
        let text: String
    }

    let replacements: [Replacement]
    let updatedSelections: [EditorSelection]?

    init(
        replacements: [Replacement],
        updatedSelections: [EditorSelection]? = nil
    ) {
        self.replacements = replacements
        self.updatedSelections = updatedSelections
    }
}
