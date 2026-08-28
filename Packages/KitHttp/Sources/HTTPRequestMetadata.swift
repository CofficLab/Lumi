import Foundation

public struct HTTPRequestMetadata: Sendable {
    public let requestId: UUID
    public let method: String
    public let url: String
    public let requestHeaders: [String: String]
    public let requestBodySizeBytes: Int
    public let requestBodyPreview: String?
    public let sentAt: Date

    public var responseStatusCode: Int?
    public var responseHeaders: [String: String]?
    public var responseBodySizeBytes: Int?
    public var responseBodyPreview: String?
    public var duration: TimeInterval?
    public var error: Error?

    public init(
        requestId: UUID,
        method: String,
        url: String,
        requestHeaders: [String: String],
        requestBodySizeBytes: Int,
        requestBodyPreview: String?,
        sentAt: Date,
        responseStatusCode: Int? = nil,
        responseHeaders: [String: String]? = nil,
        responseBodySizeBytes: Int? = nil,
        responseBodyPreview: String? = nil,
        duration: TimeInterval? = nil,
        error: Error? = nil
    ) {
        self.requestId = requestId
        self.method = method
        self.url = url
        self.requestHeaders = requestHeaders
        self.requestBodySizeBytes = requestBodySizeBytes
        self.requestBodyPreview = requestBodyPreview
        self.sentAt = sentAt
        self.responseStatusCode = responseStatusCode
        self.responseHeaders = responseHeaders
        self.responseBodySizeBytes = responseBodySizeBytes
        self.responseBodyPreview = responseBodyPreview
        self.duration = duration
        self.error = error
    }

    public var formattedBodySize: String {
        let kb = 1024
        let mb = kb * 1024
        let gb = mb * 1024

        if requestBodySizeBytes >= gb {
            return String(format: "%.2f GB", Double(requestBodySizeBytes) / Double(gb))
        } else if requestBodySizeBytes >= mb {
            return String(format: "%.2f MB", Double(requestBodySizeBytes) / Double(mb))
        } else if requestBodySizeBytes >= kb {
            return String(format: "%.2f KB", Double(requestBodySizeBytes) / Double(kb))
        } else {
            return "\(requestBodySizeBytes) bytes"
        }
    }

    public var isSuccess: Bool {
        error == nil
    }

    public var formattedResponseBodySize: String {
        guard let size = responseBodySizeBytes else { return "--" }
        let kb = 1024
        let mb = kb * 1024
        let gb = mb * 1024

        if size >= gb {
            return String(format: "%.2f GB", Double(size) / Double(gb))
        } else if size >= mb {
            return String(format: "%.2f MB", Double(size) / Double(mb))
        } else if size >= kb {
            return String(format: "%.2f KB", Double(size) / Double(kb))
        } else {
            return "\(size) bytes"
        }
    }
}
