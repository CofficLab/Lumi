import XCTest
import KernelLumi
@testable import WebServerKit

final class LumiWebServerTests: XCTestCase {
    /// 启动真实服务,注册路由,发请求验证匹配、参数解析与响应。
    func testLiveRouteEchoAndParams() async throws {
        let server = LumiWebServer(port: 0)  // 0 = OS 分配端口
        server.register([
            WebRoute(id: "echo", method: .post, path: "/echo") { request in
                let text = String(data: request.body, encoding: .utf8) ?? ""
                return try .json(["received": text])
            },
            WebRoute(id: "greet", method: .get, path: "/greet/:name") { request in
                let name = request.pathParameters["name"] ?? "world"
                return try .json(["hello": name])
            },
        ], forPlugin: "com.test.plugin")

        try await server.start()
        XCTAssertTrue(server.isRunning)
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        // POST /echo
        let echoURL = URL(string: "http://127.0.0.1:\(port)/echo")!
        var echoReq = URLRequest(url: echoURL)
        echoReq.httpMethod = "POST"
        echoReq.httpBody = Data("hello".utf8)
        let (echoData, echoResp) = try await URLSession.shared.data(for: echoReq)
        let echoHTTP = try XCTUnwrap(echoResp as? HTTPURLResponse)
        XCTAssertEqual(echoHTTP.statusCode, 200)
        XCTAssertTrue(String(data: echoData, encoding: .utf8)?.contains("hello") == true)

        // GET /greet/lumi (path 参数)
        let greetURL = URL(string: "http://127.0.0.1:\(port)/greet/lumi")!
        var greetReq = URLRequest(url: greetURL)
        greetReq.httpMethod = "GET"
        let (greetData, greetResp) = try await URLSession.shared.data(for: greetReq)
        let greetHTTP = try XCTUnwrap(greetResp as? HTTPURLResponse)
        XCTAssertEqual(greetHTTP.statusCode, 200)
        XCTAssertTrue(String(data: greetData, encoding: .utf8)?.contains("lumi") == true)

        await server.stop()
        XCTAssertFalse(server.isRunning)
    }

    /// 未匹配路径返回 404。
    func testNotFound() async throws {
        let server = LumiWebServer(port: 0)
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)

        let url = URL(string: "http://127.0.0.1:\(port)/no-such-route")!
        let (_, resp) = try await URLSession.shared.data(for: URLRequest(url: url))
        let http = try XCTUnwrap(resp as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 404)

        await server.stop()
    }

    /// 开启 token 鉴权时,无凭证返回 401、正确凭证放行。
    func testAuthToken() async throws {
        let server = LumiWebServer(port: 0, authToken: "s3cret")
        server.register([
            WebRoute(id: "ping", method: .get, path: "/ping") { _ in .text("pong") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)

        // 无 token -> 401
        let noTokenURL = URL(string: "http://127.0.0.1:\(port)/ping")!
        let (_, resp1) = try await URLSession.shared.data(for: URLRequest(url: noTokenURL))
        XCTAssertEqual((resp1 as? HTTPURLResponse)?.statusCode, 401)

        // 带 token -> 200
        var req = URLRequest(url: noTokenURL)
        req.setValue("Bearer s3cret", forHTTPHeaderField: "Authorization")
        let (data, resp2) = try await URLSession.shared.data(for: req)
        XCTAssertEqual((resp2 as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), "pong")

        await server.stop()
    }
}
