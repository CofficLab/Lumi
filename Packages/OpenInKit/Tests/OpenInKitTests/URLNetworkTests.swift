import Foundation
import Testing
@testable import OpenInKit

@Suite("URL network detection")
struct URLNetworkTests {

    @Test("detects http and https")
    func isNetworkURL() {
        #expect(URL(string: "https://example.com")!.isNetworkURL)
        #expect(URL(string: "http://localhost:8080")!.isNetworkURL)
        #expect(URL(string: "HTTPS://example.com")!.isNetworkURL)
        #expect(URL(string: "HTTP://localhost:8080")!.isNetworkURL)
        #expect(!URL(fileURLWithPath: "/Users/me/project").isNetworkURL)
        #expect(!URL(string: "file:///tmp/a")!.isNetworkURL)
    }
}
