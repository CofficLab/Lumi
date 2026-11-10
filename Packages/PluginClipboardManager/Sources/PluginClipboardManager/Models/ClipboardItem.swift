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
    /// 富文本负载的存储上限。超过上限时降级为只保存纯文本，避免历史库被单个大文档撑爆。
    public static let maxRichTextPayloadBytes = 1_048_576

    public let id: UUID
    public let type: ClipboardItemType
    public let content: String // For text/html: content; For file: path; For image: filename/path
    public let timestamp: Date
    public var isPinned: Bool
    public var appName: String? // Source app
    public var searchKeywords: String // For easier searching
    /// 捕获时剪贴板提供的 RTF 原始数据（可选，用于恢复格式与链接）。
    public let richTextRTF: Data?
    /// 捕获时剪贴板提供的 HTML 字符串（可选，用于恢复格式与链接）。
    public let richTextHTML: String?
    
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
    
    public init(
        type: ClipboardItemType,
        content: String,
        appName: String? = nil,
        isPinned: Bool = false,
        richTextRTF: Data? = nil,
        richTextHTML: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.timestamp = Date()
        self.isPinned = isPinned
        self.appName = appName
        self.searchKeywords = content.lowercased()
        let payload = Self.sanitizedRichText(rtf: richTextRTF, html: richTextHTML)
        self.richTextRTF = payload.rtf
        self.richTextHTML = payload.html
    }

    /// 富文本负载超过总上限时整体丢弃，退化为纯文本。
    static func sanitizedRichText(rtf: Data?, html: String?) -> (rtf: Data?, html: String?) {
        guard rtf != nil || html != nil else { return (nil, nil) }
        let totalBytes = (rtf?.count ?? 0) + (html?.utf8.count ?? 0)
        guard totalBytes <= Self.maxRichTextPayloadBytes else { return (nil, nil) }
        return (rtf, html)
    }
}
