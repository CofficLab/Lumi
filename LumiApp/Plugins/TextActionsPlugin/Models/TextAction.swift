import Foundation
import AppKit

enum TextActionType: String, CaseIterable, Identifiable, Codable, Sendable {
    case copy
    case search
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .copy: return String(localized: "Copy", table: "TextActions")
        case .search: return String(localized: "Search", table: "TextActions")
        }
    }
    
    var icon: String {
        switch self {
        case .copy: return "doc.on.doc"
        case .search: return "magnifyingglass"
        }
    }
}

struct TextAction: Identifiable, Equatable, Sendable {
    let id = UUID()
    let type: TextActionType
    let text: String // The text to act upon
    
    func perform() {
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
