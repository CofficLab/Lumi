import Foundation

struct BrowserCDPAdapter: Sendable {
    let endpoint: URL

    static func defaultEndpoint(port: Int = 9222) -> URL? {
        URL(string: "http://127.0.0.1:\(port)/json")
    }

    var webSocketDiscoveryURL: URL {
        endpoint
    }
}
