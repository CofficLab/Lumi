import Foundation

enum EditorCommandCategory: String, CaseIterable {
    case find
    case navigation
    case workbench
    case multiCursor = "multi-cursor"
    case format
    case lsp
    case save
    case chat
    case other

    var displayTitle: String {
        switch self {
        case .find:
            return "Find"
        case .navigation:
            return "Navigation"
        case .workbench:
            return "Workbench"
        case .multiCursor:
            return "Multi-Cursor"
        case .format:
            return "Formatting"
        case .lsp:
            return "Language"
        case .save:
            return "Saving"
        case .chat:
            return "Chat"
        case .other:
            return "Other"
        }
    }

    static let orderedCases: [EditorCommandCategory] = [
        .find,
        .navigation,
        .workbench,
        .multiCursor,
        .format,
        .lsp,
        .save,
        .chat,
        .other
    ]

    static func resolve(_ rawValue: String?) -> EditorCommandCategory {
        EditorCommandCategory(rawValue: rawValue ?? "") ?? .other
    }

    static func orderIndex(for rawValue: String?) -> Int {
        let category = resolve(rawValue)
        return orderedCases.firstIndex(of: category) ?? Int.max
    }
}

extension Array where Element == EditorCommandSuggestion {
    func sortedForCommandPresentation() -> [EditorCommandSuggestion] {
        sorted { lhs, rhs in
            let lhsCategory = EditorCommandCategory.orderIndex(for: lhs.category)
            let rhsCategory = EditorCommandCategory.orderIndex(for: rhs.category)
            if lhsCategory != rhsCategory {
                return lhsCategory < rhsCategory
            }
            if lhs.order != rhs.order {
                return lhs.order < rhs.order
            }
            let lhsTitle = lhs.title.localizedLowercase
            let rhsTitle = rhs.title.localizedLowercase
            if lhsTitle != rhsTitle {
                return lhsTitle < rhsTitle
            }
            return lhs.id < rhs.id
        }
    }
}

enum EditorCommandCategoryScope {
    static let lspActions: Set<EditorCommandCategory> = [
        .navigation,
        .format,
        .lsp
    ]

    static let editorContextMenu: Set<EditorCommandCategory> = [
        .navigation,
        .multiCursor,
        .format,
        .lsp,
        .chat
    ]
}
