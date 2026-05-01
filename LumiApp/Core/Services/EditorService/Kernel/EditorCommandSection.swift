import Foundation

struct EditorCommandSection: Identifiable {
    let category: EditorCommandCategory
    let commands: [EditorCommandSuggestion]

    var id: String { category.rawValue }
    var title: String { category.displayTitle }
}
