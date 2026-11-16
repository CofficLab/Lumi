import Darwin
import Foundation
import XCTest
import ProviderWebServer
@testable import KitWebServer

/// 回环 Host 校验：DNS rebinding 不得把匿名 Web API 暴露给任意网页（回归 #1162）。
///
/// 服务只绑定 127.0.0.1，但「连接来自回环」不是信任边界：攻击者把自己控制的域名
/// 重新解析到 127.0.0.1 后，浏览器仍视其为 same-origin，于是
/// `Origin` 与 `Host` 两边都是攻击者可控值，既有的跨源写保护完全失效，
/// 而 GET 根本不进那条检查。这里锁住 Host 白名单在鉴权、CORS 与路由之前生效。
final class LumiWebServerHostValidationTests: XCTestCase {

    // MARK: - 原始 HTTP 客户端

    private struct RawHTTPResponse {
        let status: Int
        let headers: [String: String]
        let body: String
    }

    private enum RawHTTPError: Error {
        case socketFailed(Int32)
        case connectFailed(Int32)
        case sendFailed
        case malformedResponse
    }

    /// 用 POSIX socket 发原始 HTTP/1.1 请求。
    ///
    /// 必须绕开 URLSession：它会按 URL 自行改写 `Host` 头，
    /// 用它无法构造出「连到回环、但 Host 是攻击者域名」的 rebinding 请求。
    private func sendRawRequest(
        port: Int,
        method: String,
        path: String,
        headers: [(String, String)] = []
    ) throws -> RawHTTPResponse {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw RawHTTPError.socketFailed(errno) }
        defer { close(fd) }

        // 收发都设超时：断言失败也不能让测试永久挂住。
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        let timeoutSize = socklen_t(MemoryLayout<timeval>.size)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, timeoutSize)
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, timeoutSize)

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(UInt16(clamping: port)).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connected == 0 else { throw RawHTTPError.connectFailed(errno) }

        var text = "\(method) \(path) HTTP/1.1\r\n"
        for (name, value) in headers {
            text += "\(name): \(value)\r\n"
        }
        // 显式给出 body 长度，避免服务端等 EOF 才收完请求体。
        if !headers.contains(where: { $0.0.lowercased() == "content-length" }) {
            text += "Content-Length: 0\r\n"
        }
        text += "Connection: close\r\n\r\n"

        let bytes = Array(text.utf8)
        let sent = bytes.withUnsafeBufferPointer { send(fd, $0.baseAddress, $0.count, 0) }
        guard sent == bytes.count else { throw RawHTTPError.sendFailed }

        var received = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let count = recv(fd, &buffer, buffer.count, 0)
            guard count > 0 else { break }
            received.append(contentsOf: buffer[0..<count])
        }

        guard let raw = String(data: received, encoding: .utf8) else {
            throw RawHTTPError.malformedResponse
        }
        let sections = raw.components(separatedBy: "\r\n\r\n")
        let lines = sections[0].components(separatedBy: "\r\n")
        let statusTokens = (lines.first ?? "").split(separator: " ")
        guard statusTokens.count >= 2, let status = Int(statusTokens[1]) else {
            throw RawHTTPError.malformedResponse
        }
        var responseHeaders: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colon]).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            responseHeaders[name] = value
        }
        let body = sections.count > 1 ? sections[1...].joined(separator: "\r\n\r\n") : ""
        return RawHTTPResponse(status: status, headers: responseHeaders, body: body)
    }

    // MARK: - 装配

    /// 起一个真实监听的服务器，注册读/写两条路由，并挂上请求日志便于断言「未进入路由」。
    private func makeServer(
        authToken: String? = nil,
        corsPolicy: WebCORSPolicy? = nil
    ) async throws -> (server: LumiWebServer, port: Int, sink: WebInMemoryRequestLogSink) {
        let sink = WebInMemoryRequestLogSink()
        let server = LumiWebServer(port: 0, authToken: authToken, corsPolicy: corsPolicy)
        server.setRequestLogSink(sink)
        server.register([
            WebRoute(id: "ping", method: .get, path: "/ping") { _ in .text("pong") },
            WebRoute(id: "select", method: .post, path: "/state") { _ in .text("executed") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        return (server, port, sink)
    }

    private struct ErrorEnvelope: Decodable {
        struct Body: Decodable {
            let code: String
            let message: String
        }
        let error: Body
    }

    private func assertForbidden(_ response: RawHTTPResponse, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(response.status, 403, file: file, line: line)
        let envelope = try JSONDecoder().decode(ErrorEnvelope.self, from: Data(response.body.utf8))
        XCTAssertEqual(envelope.error.code, "forbidden", file: file, line: line)
    }

    // MARK: - rebinding 读请求

    /// rebinding 后的 GET 必须在进入路由前被拒绝，不得回显任何业务数据。
    func testReboundHostReadIsRejected() async throws {
        let (server, port, sink) = try await makeServer()
        defer { Task { await server.stop() } }

        let response = try sendRawRequest(
            port: port, method: "GET", path: "/ping",
            headers: [("Host", "rebind.example:\(port)")]
        )

        try assertForbidden(response)
        XCTAssertFalse(response.body.contains("pong"))
        // 未进入路由：日志里没有归属插件。
        let log = try XCTUnwrap(sink.recentLogs.first)
        XCTAssertEqual(log.statusCode, 403)
        XCTAssertNil(log.pluginID)
    }

    /// 自描述端点同样不得泄露路由清单。
    func testReboundHostDiscoveryIsRejected() async throws {
        let (server, port, _) = try await makeServer()
        defer { Task { await server.stop() } }

        let response = try sendRawRequest(
            port: port, method: "GET", path: "/api/plugins",
            headers: [("Host", "rebind.example:\(port)")]
        )

        try assertForbidden(response)
        XCTAssertFalse(response.body.contains("com.test.plugin"))
    }

    // MARK: - rebinding 写请求

    /// issue 里的完整攻击链：Host 与 Origin 同为攻击者域名、Sec-Fetch-Site 为
    /// same-origin，旧实现会放行并执行 handler。
    func testReboundHostSameOriginWriteIsRejected() async throws {
        let (server, port, sink) = try await makeServer()
        defer { Task { await server.stop() } }

        let response = try sendRawRequest(
            port: port, method: "POST", path: "/state",
            headers: [
                ("Host", "rebind.example:\(port)"),
                ("Origin", "http://rebind.example:\(port)"),
                ("Sec-Fetch-Site", "same-origin"),
            ]
        )

        try assertForbidden(response)
        XCTAssertFalse(response.body.contains("executed"))
        XCTAssertNil(try XCTUnwrap(sink.recentLogs.first).pluginID)
    }

    /// Host 校验早于鉴权：即便带上正确 token，rebinding 请求也不得进入路由。
    func testReboundHostRejectedBeforeAuthentication() async throws {
        let (server, port, sink) = try await makeServer(authToken: "s3cret")
        defer { Task { await server.stop() } }

        let response = try sendRawRequest(
            port: port, method: "GET", path: "/ping",
            headers: [
                ("Host", "rebind.example:\(port)"),
                ("Authorization", "Bearer s3cret"),
            ]
        )

        try assertForbidden(response)
        XCTAssertNil(try XCTUnwrap(sink.recentLogs.first).pluginID)
    }

    /// Host 校验早于 CORS 预检：rebinding 页面拿不到任何允许头。
    func testReboundHostPreflightIsRejected() async throws {
        let (server, port, _) = try await makeServer(corsPolicy: WebCORSPolicy())
        defer { Task { await server.stop() } }

        let response = try sendRawRequest(
            port: port, method: "OPTIONS", path: "/state",
            headers: [
                ("Host", "rebind.example:\(port)"),
                ("Origin", "http://rebind.example:\(port)"),
            ]
        )

        try assertForbidden(response)
        XCTAssertNil(response.headers["access-control-allow-origin"])
    }

    /// 重复 Host 头时只要有一个不是回环就拒绝，不留「取第一个还是最后一个」的歧义。
    func testDuplicateHostWithNonLoopbackIsRejected() async throws {
        let (server, port, sink) = try await makeServer()
        defer { Task { await server.stop() } }

        let response = try sendRawRequest(
            port: port, method: "GET", path: "/ping",
            headers: [
                ("Host", "127.0.0.1:\(port)"),
                ("Host", "rebind.example:\(port)"),
            ]
        )

        try assertForbidden(response)
        XCTAssertNil(try XCTUnwrap(sink.recentLogs.first).pluginID)
    }

    // MARK: - 合法本机访问不受影响

    /// 回环的各种合法写法（IPv4、localhost、IPv6 带括号、大写）都照常放行。
    func testLoopbackHostFormsAreAllowed() async throws {
        let (server, port, _) = try await makeServer()
        defer { Task { await server.stop() } }

        for host in ["127.0.0.1:\(port)", "localhost:\(port)", "[::1]:\(port)", "LOCALHOST:\(port)"] {
            let response = try sendRawRequest(
                port: port, method: "GET", path: "/ping",
                headers: [("Host", host)]
            )
            XCTAssertEqual(response.status, 200, "Host \(host) 被误拒")
            XCTAssertEqual(response.body, "pong")
        }
    }

    /// 同源写请求在 Host 校验加入后仍然可用。
    func testLoopbackSameOriginWriteStillAllowed() async throws {
        let (server, port, _) = try await makeServer()
        defer { Task { await server.stop() } }

        let response = try sendRawRequest(
            port: port, method: "POST", path: "/state",
            headers: [
                ("Host", "127.0.0.1:\(port)"),
                ("Origin", "http://127.0.0.1:\(port)"),
                ("Sec-Fetch-Site", "same-origin"),
            ]
        )

        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.body, "executed")
    }

    /// 不带 Host 的非浏览器调用方（HTTP/1.0）保持可用。
    func testRequestWithoutHostIsAllowed() async throws {
        let (server, port, _) = try await makeServer()
        defer { Task { await server.stop() } }

        let response = try sendRawRequest(port: port, method: "GET", path: "/ping")

        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.body, "pong")
    }

    // MARK: - 白名单判定

    /// 只有回环主机名本身放行；子串、后缀、其它端口与整数 IP 形式一律拒绝。
    func testLoopbackHostAllowlist() {
        let port = 7310
        let accepted: [String?] = [
            "127.0.0.1", "127.0.0.1:7310", "localhost", "localhost:7310",
            "LOCALHOST:7310", "::1", "[::1]", "[::1]:7310", " 127.0.0.1:7310 ",
            // 不带 Host 的不是浏览器页面，rebinding 无法借此绕过。
            nil, "", "   ",
        ]
        for host in accepted {
            XCTAssertTrue(
                LumiWebServer.isLoopbackHost(host, defaultPort: port),
                "Host \(host ?? "nil") 应被放行"
            )
        }

        let rejected: [String] = [
            "rebind.example", "rebind.example:7310",
            // 后缀 / 子串混淆。
            "127.0.0.1.evil.example", "localhost.evil.example", "evillocalhost",
            "notlocalhost:7310", "127.0.0.1x",
            // 其它端口与整数 IP 形式。
            "127.0.0.1:9999", "localhost:9999", "2130706433",
            // 非回环地址与畸形值。
            "192.168.1.10", "127.0.0.2", "[::2]:7310", "127.0.0.1:7310:80",
            "http://127.0.0.1:7310", "127.0.0.1\\@evil.example",
        ]
        for host in rejected {
            XCTAssertFalse(
                LumiWebServer.isLoopbackHost(host, defaultPort: port),
                "Host \(host) 应被拒绝"
            )
        }
    }
}