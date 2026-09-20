import Foundation

/// A bounded snapshot of one element selected inside an HTML preview.
public struct HTMLPreviewElementReference: Sendable, Equatable, Codable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let selector: String
    public let tagName: String
    public let label: String
    public let textPreview: String?
    public let outerHTML: String
    public let isOuterHTMLTruncated: Bool
    public let blockID: String?
    public let blockLabel: String?
    public let attributes: [String: String]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        selector: String,
        tagName: String,
        label: String,
        textPreview: String? = nil,
        outerHTML: String,
        isOuterHTMLTruncated: Bool = false,
        blockID: String? = nil,
        blockLabel: String? = nil,
        attributes: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.selector = selector
        self.tagName = tagName
        self.label = label
        self.textPreview = textPreview
        self.outerHTML = outerHTML
        self.isOuterHTMLTruncated = isOuterHTMLTruncated
        self.blockID = blockID
        self.blockLabel = blockLabel
        self.attributes = attributes
    }
}
