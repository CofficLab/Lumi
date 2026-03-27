import Foundation
import SwiftData

/// HTTP 请求日志项 - SwiftData 模型
@Model
final class RequestLogItem {
    @Attribute(.unique) var id: UUID
    var requestId: UUID
    var timestamp: Date

    // Request
    var method: String
    var requestURL: String
    var requestHeadersJSON: String?
    var requestBodySize: Int
    var requestBodyPreview: String?

    // Response
    var responseStatusCode: Int?
    var responseHeadersJSON: String?
    var isSuccess: Bool
    var errorMessage: String?
    var duration: Double?

    init(
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
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
        self.duration = duration
    }

    static func predicate(from startTime: Date, to endTime: Date) -> Predicate<RequestLogItem> {
        #Predicate<RequestLogItem> { item in
            item.timestamp >= startTime && item.timestamp <= endTime
        }
    }

    static func predicate(isSuccess: Bool) -> Predicate<RequestLogItem> {
        #Predicate<RequestLogItem> { item in
            item.isSuccess == isSuccess
        }
    }
}

struct RequestLogItemDTO: Sendable {
    let id: UUID
    let requestId: UUID
    let timestamp: Date
    let method: String
    let requestURL: String
    let requestBodySize: Int
    let responseStatusCode: Int?
    let isSuccess: Bool
    let errorMessage: String?
    let duration: Double?

    init(from item: RequestLogItem) {
        self.id = item.id
        self.requestId = item.requestId
        self.timestamp = item.timestamp
        self.method = item.method
        self.requestURL = item.requestURL
        self.requestBodySize = item.requestBodySize
        self.responseStatusCode = item.responseStatusCode
        self.isSuccess = item.isSuccess
        self.errorMessage = item.errorMessage
        self.duration = item.duration
    }
}

