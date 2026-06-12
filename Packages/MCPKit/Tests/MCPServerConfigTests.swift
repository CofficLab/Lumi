import XCTest
@testable import MCPKit

final class MCPServerConfigTests: XCTestCase {
    func testServerConfigDefaultsToEnabledStdioCompatibleConfig() {
        let config = MCPServerConfig(
            name: "shell",
            command: "uvx",
            args: ["mcp-server"],
            env: [:]
        )

        XCTAssertEqual(config.id, "shell")
        XCTAssertEqual(config.name, "shell")
        XCTAssertEqual(config.command, "uvx")
        XCTAssertEqual(config.args, ["mcp-server"])
        XCTAssertEqual(config.env, [:])
        XCTAssertFalse(config.disabled)
        XCTAssertNil(config.homepage)
        XCTAssertNil(config.url)
        XCTAssertNil(config.transportType)
    }

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

    func testTransportTypeCodableRawValues() throws {
        let data = try JSONEncoder().encode([MCPTransportType.stdio, .sse])
        let decoded = try JSONDecoder().decode([MCPTransportType].self, from: data)

        XCTAssertEqual(decoded, [.stdio, .sse])
        XCTAssertEqual(MCPTransportType.stdio.rawValue, "stdio")
        XCTAssertEqual(MCPTransportType.sse.rawValue, "sse")
    }
}
