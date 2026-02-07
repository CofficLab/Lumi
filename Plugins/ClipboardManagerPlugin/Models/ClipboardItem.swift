import Foundation
import AppKit

enum ClipboardItemType: String, Codable, Sendable {
    case text
    case image
    case file
    case html
    case color
}

struct ClipboardItem: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let type: ClipboardItemType
    let content: String // For text/html: content; For file: path; For image: filename/path
    let timestamp: Date
    var isPinned: Bool
    var appName: String? // Source app
    var searchKeywords: String // For easier searching
    
    // For display
    var title: String {
        switch type {
        case .text, .html:
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        case .file:
            return URL(fileURLWithPath: content).lastPathComponent
        case .image:
            return "Image"
        case .color:
            return content
        }
    }
    
    init(type: ClipboardItemType, content: String, appName: String? = nil, isPinned: Bool = false) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.timestamp = Date()
        self.isPinned = isPinned
        self.appName = appName
        self.searchKeywords = content.lowercased()
    }
}
