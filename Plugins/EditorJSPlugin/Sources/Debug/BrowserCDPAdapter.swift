import Foundation

public struct BrowserCDPAdapter: Sendable {
    public let endpoint: URL

    public static func defaultEndpoint(port: Int = 9222) -> URL? {
        URL(string: "http://127.0.0.1:\(port)/json")
    }

    public var webSocketDiscoveryURL: URL {
        endpoint
    }
}
