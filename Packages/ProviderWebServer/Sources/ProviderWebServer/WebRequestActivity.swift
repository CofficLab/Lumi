import Foundation

/// A handled local-web request, suitable for UI feedback and audit trails.
///
/// Network implementations emit this value after a route handler completes;
/// keeping it in the provider package lets V2 hosts consume the event without
/// importing the retired `KernelLumi` web types.
public struct WebRequestActivity: Sendable, Equatable {
    public let pluginID: String
    public let method: String
    public let path: String
    public let description: String?
    public let statusCode: Int
    public let timestamp: Date

    public init(
        pluginID: String,
        method: String,
        path: String,
        description: String?,
        statusCode: Int,
        timestamp: Date = Date()
    ) {
        self.pluginID = pluginID
        self.method = method
        self.path = path
        self.description = description
        self.statusCode = statusCode
        self.timestamp = timestamp
    }

    public var isMutation: Bool {
        switch method.uppercased() {
        case "POST", "PUT", "PATCH", "DELETE": true
        default: false
        }
    }

    public var isSuccess: Bool { (200..<300).contains(statusCode) }
}
