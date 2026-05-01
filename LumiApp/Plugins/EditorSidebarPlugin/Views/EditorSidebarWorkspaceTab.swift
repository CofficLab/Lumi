import SwiftUI

// MARK: - Tab

/// 编辑器侧边栏工作区标签页
enum EditorSidebarWorkspaceTab: String, CaseIterable, Identifiable {
    case explorer
    case openEditors
    case outline
    case problems
    case searchResults
    case references
    case workspaceSymbols
    case callHierarchy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explorer:
            "Explorer"
        case .openEditors:
            "Open Editors"
        case .outline:
            "Outline"
        case .problems:
            "Problems"
        case .searchResults:
            "Search"
        case .references:
            "References"
        case .workspaceSymbols:
            "Symbols"
        case .callHierarchy:
            "Calls"
        }
    }

    var systemImage: String {
        switch self {
        case .explorer:
            "folder"
        case .openEditors:
            "sidebar.left"
        case .outline:
            "list.bullet.indent"
        case .problems:
            "exclamationmark.bubble"
        case .searchResults:
            "magnifyingglass"
        case .references:
            "arrow.triangle.branch"
        case .workspaceSymbols:
            "text.magnifyingglass"
        case .callHierarchy:
            "point.3.connected.trianglepath.dotted"
        }
    }

    var isContextual: Bool {
        switch self {
        case .explorer, .openEditors, .outline:
            return false
        case .problems, .searchResults, .references, .workspaceSymbols, .callHierarchy:
            return true
        }
    }

    var priority: Int {
        switch self {
        case .explorer:
            return 0
        case .openEditors:
            return 1
        case .outline:
            return 2
        case .problems:
            return 10
        case .searchResults:
            return 11
        case .references:
            return 12
        case .workspaceSymbols:
            return 13
        case .callHierarchy:
            return 14
        }
    }
}
