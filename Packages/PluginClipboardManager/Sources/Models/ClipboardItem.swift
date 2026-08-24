import Foundation
import AppKit

public enum ClipboardItemType: String, Codable, Sendable {
    case text
    case image
    case file
    case html
    case color
}

public struct ClipboardItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let type: ClipboardItemType
    public let content: String // For text/html: content; For file: path; For image: filename/path
    public let timestamp: Date
    public var isPinned: Bool
    public var appName: String? // Source app
    public var searchKeywords: String // For easier searching
    
    // For display
    public var title: String {
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
    
    public init(type: ClipboardItemType, content: String, appName: String? = nil, isPinned: Bool = false) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.timestamp = Date()
        self.isPinned = isPinned
        self.appName = appName
        self.searchKeywords = content.lowercased()
    }
}
