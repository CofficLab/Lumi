import Foundation
import LumiCoreKit

public enum EditorCommandCategory: String, CaseIterable, Sendable {
    case edit
    case find
    case navigation
    case workbench
    case multiCursor = "multi-cursor"
    case format
    case lsp
    case save
    case chat
    case other

    public var displayTitle: String {
        switch self {
        case .edit:
            return LumiPluginLocalization.string("Edit", bundle: .module)
        case .find:
            return LumiPluginLocalization.string("Find", bundle: .module)
        case .navigation:
            return LumiPluginLocalization.string("Navigation", bundle: .module)
        case .workbench:
            return LumiPluginLocalization.string("Workbench", bundle: .module)
        case .multiCursor:
            return LumiPluginLocalization.string("Multi-Cursor", bundle: .module)
        case .format:
            return LumiPluginLocalization.string("Formatting", bundle: .module)
        case .lsp:
            return LumiPluginLocalization.string("Language", bundle: .module)
        case .save:
            return LumiPluginLocalization.string("Saving", bundle: .module)
        case .chat:
            return LumiPluginLocalization.string("Chat", bundle: .module)
        case .other:
            return LumiPluginLocalization.string("Other", bundle: .module)
        }
    }

    public static let orderedCases: [EditorCommandCategory] = [
        .edit,
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

    public static func resolve(_ rawValue: String?) -> EditorCommandCategory {
        EditorCommandCategory(rawValue: rawValue ?? "") ?? .other
    }

    public static func orderIndex(for rawValue: String?) -> Int {
        let category = resolve(rawValue)
        return orderedCases.firstIndex(of: category) ?? Int.max
    }
}

public extension Array where Element == EditorCommandSuggestion {
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

public enum EditorCommandCategoryScope {
    public static let lspActions: Set<EditorCommandCategory> = [
        .navigation,
        .format,
        .lsp
    ]

    public static let editorContextMenu: Set<EditorCommandCategory> = [
        .navigation,
        .multiCursor,
        .format,
        .lsp,
        .chat
    ]
}
