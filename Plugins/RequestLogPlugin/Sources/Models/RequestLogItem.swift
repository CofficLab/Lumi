import Foundation
import SwiftData

/// HTTP 请求日志项 - SwiftData 模型
@Model
public final class RequestLogItem {
    @Attribute(.unique) public var id: UUID
    public var requestId: UUID
    public var timestamp: Date

    // Request
    public var method: String
    public var requestURL: String
    public var requestHeadersJSON: String?
    public var requestBodySize: Int
    public var requestBodyPreview: String?

    // Response
    public var responseStatusCode: Int?
    public var responseHeadersJSON: String?
    public var responseBodySize: Int?
    public var responseBodyPreview: String?
    public var isSuccess: Bool
    public var errorMessage: String?
    public var duration: Double?

    public init(
        id: UUID = UUID(),
        requestId: UUID,
        timestamp: Date,
        method: String,
        requestURL: String,
        requestHeadersJSON: String?,
        requestBodySize: Int,
        requestBodyPreview: String?,
        responseStatusCode: Int?,
        responseHeadersJSON: String?,
        responseBodySize: Int?,
        responseBodyPreview: String?,
        isSuccess: Bool,
        errorMessage: String?,
        duration: Double?
    ) {
        self.id = id
        self.requestId = requestId
        self.timestamp = timestamp
        self.method = method
        self.requestURL = requestURL
        self.requestHeadersJSON = requestHeadersJSON
        self.requestBodySize = requestBodySize
        self.requestBodyPreview = requestBodyPreview
        self.responseStatusCode = responseStatusCode
        self.responseHeadersJSON = responseHeadersJSON
        self.responseBodySize = responseBodySize
        self.responseBodyPreview = responseBodyPreview
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
        self.duration = duration
    }

    public static func predicate(from startTime: Date, to endTime: Date) -> Predicate<RequestLogItem> {
        #Predicate<RequestLogItem> { item in
            item.timestamp >= startTime && item.timestamp <= endTime
        }
    }

    public static func predicate(isSuccess: Bool) -> Predicate<RequestLogItem> {
        #Predicate<RequestLogItem> { item in
            item.isSuccess == isSuccess
        }
    }
}

public struct RequestLogItemDTO: Sendable, Identifiable {
    public let id: UUID
    public let requestId: UUID
    public let timestamp: Date
    public let method: String
    public let requestURL: String
    public let requestBodySize: Int
    public let requestBodyPreview: String?
    public let responseStatusCode: Int?
    public let responseBodySize: Int?
    public let responseBodyPreview: String?
    public let isSuccess: Bool
    public let errorMessage: String?
    public let duration: Double?

    public init(from item: RequestLogItem) {
        self.id = item.id
        self.requestId = item.requestId
        self.timestamp = item.timestamp
        self.method = item.method
        self.requestURL = item.requestURL
        self.requestBodySize = item.requestBodySize
        self.requestBodyPreview = item.requestBodyPreview
        self.responseStatusCode = item.responseStatusCode
        self.responseBodySize = item.responseBodySize
        self.responseBodyPreview = item.responseBodyPreview
        self.isSuccess = item.isSuccess
        self.errorMessage = item.errorMessage
        self.duration = item.duration
    }
}
