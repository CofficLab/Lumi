import XCTest
@testable import MCPKit

final class MCPServerConfigTests: XCTestCase {
    func testServerConfigRoundTripsTransportType() throws {
        let config = MCPServerConfig(
            name: "filesystem",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem"],
            env: ["TOKEN": "secret"],
            disabled: true,
            homepage: "https://example.com",
            url: "https://example.com/sse",
            transportType: .sse
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(MCPServerConfig.self, from: data)

        XCTAssertEqual(decoded, config)
        XCTAssertEqual(decoded.id, "filesystem")
    }
}
