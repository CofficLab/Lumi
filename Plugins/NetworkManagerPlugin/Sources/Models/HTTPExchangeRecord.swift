import Foundation
import SwiftData

/// A lossless-enough local record of one HTTP exchange.
///
/// Headers are stored as JSON data instead of a Swift dictionary so that the
/// exact keys and values can be retained without exposing a transformed view
/// to the persistence layer. Bodies are kept as their original bytes.
@Model
public final class HTTPExchangeRecord {
    public var id: UUID
    public var startedAt: Date
    public var finishedAt: Date?
    public var duration: TimeInterval?

    public var requestMethod: String
    public var requestURL: String
    public var requestHeadersJSON: Data
    public var requestBody: Data?
    public var requestDetailsJSON: Data

    public var responseURL: String?
    public var responseStatusCode: Int?
    public var responseHTTPVersion: String?
    public var responseHeadersJSON: Data?
    public var responseBody: Data?
    public var responseMIMEType: String?
    public var responseExpectedContentLength: Int64?
    public var responseTextEncodingName: String?

    public var errorDomain: String?
    public var errorCode: Int?
    public var errorDescription: String?
    public var errorDetailsJSON: Data?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        requestMethod: String,
        requestURL: String,
        requestHeadersJSON: Data,
        requestBody: Data?,
        requestDetailsJSON: Data
    ) {
        self.id = id
        self.startedAt = startedAt
        self.requestMethod = requestMethod
        self.requestURL = requestURL
        self.requestHeadersJSON = requestHeadersJSON
        self.requestBody = requestBody
        self.requestDetailsJSON = requestDetailsJSON
    }
}
