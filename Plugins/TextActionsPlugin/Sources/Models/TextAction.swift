import Foundation
import AppKit

public enum TextActionType: String, CaseIterable, Identifiable, Codable, Sendable {
    case copy
    case search
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .copy: return String(localized: "Copy", bundle: .module)
        case .search: return String(localized: "Search", bundle: .module)
        }
    }
    
    public var icon: String {
        switch self {
        case .copy: return "doc.on.doc"
        case .search: return "magnifyingglass"
        }
    }
}

public struct TextAction: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let type: TextActionType
    public let text: String // The text to act upon
    
    public func perform() {
        switch type {
        case .copy:
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            
        case .search:
            if let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
