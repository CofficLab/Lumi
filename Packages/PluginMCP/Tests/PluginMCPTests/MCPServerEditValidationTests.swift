import Foundation
import Testing
import KitMCP
@testable import PluginMCP

/// MCP 服务器表单的校验规则必须区分传输方式（#1159）。
///
/// HTTP 传输仅凭 URL 建连，从不读取 command；若无条件要求非空
/// command，合法的远程服务器配置就无法保存，用户只能编造无意义的占位值。
@MainActor
@Suite("MCP 服务器表单校验")
struct MCPServerEditValidationTests {
    @Test("HTTP 传输允许空 command")
    func httpAllowsEmptyCommand() {
        let error = MCPServerEditSheet.validationError(
            name: "Remote",
            command: "",
            url: "https://example.com/mcp",
            transport: .streamableHTTP
        )
        #expect(error == nil)
    }

    @Test("HTTP 传输仍要求 URL")
    func httpRequiresURL() {
        let error = MCPServerEditSheet.validationError(
            name: "Remote",
            command: "",
            url: "",
            transport: .streamableHTTP
        )
        #expect(error == "URL is required for HTTP transport.")
    }

    @Test("stdio 传输仍要求 command")
    func stdioRequiresCommand() {
        let error = MCPServerEditSheet.validationError(
            name: "Local",
            command: "",
            url: "",
            transport: .stdio
        )
        #expect(error == "Command is required.")
    }

    @Test("两种传输都要求名称")
    func nameRequiredForBothTransports() {
        for transport in [MCPTransport.stdio, MCPTransport.streamableHTTP] {
            let error = MCPServerEditSheet.validationError(
                name: "",
                command: "xcrun",
                url: "https://example.com/mcp",
                transport: transport
            )
            #expect(error == "Name is required.")
        }
    }

    @Test("完整的 stdio 配置通过校验")
    func stdioValidConfigurationPasses() {
        let error = MCPServerEditSheet.validationError(
            name: "Local",
            command: "xcrun",
            url: "",
            transport: .stdio
        )
        #expect(error == nil)
    }
}