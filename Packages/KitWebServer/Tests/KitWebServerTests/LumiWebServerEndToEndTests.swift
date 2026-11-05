import Foundation
import XCTest
import ProviderWebServer
import KitWebServer

/// 端到端冒烟测试：真起一个 HTTP 服务，打通「注册路由 → 真实请求 → 响应」。
///
/// 与 `LumiWebServerPipelineTests` 的区别：这里聚焦**端到端可达**，
/// 验证声明式路由（含路径参数）、查询参数与请求体在真实网络栈上都能工作。
final class LumiWebServerEndToEndTests: XCTestCase {
    /// 声明式注册的端点在真实 HTTP 上可达，路径参数正确解析。
    func testDeclaredRoutesAreReachableOverHTTP() async throws {
        let server = LumiWebServer(port: 0)
        server.register(
            WebRouteBuilder(prefix: "smoke")
                .get("/api/v1/smoke/echo/:id", description: "回显路径参数") { request in
                    let id = try request.requirePathParameter("id")
                    return try .api(["id": id] as [String: String])
                }
                .get("/api/v1/smoke/query", description: "回显查询参数") { request in
                    let name = request.queryParameter("name") ?? "none"
                    return try .api(["name": name] as [String: String])
                }
                .post("/api/v1/smoke/body", description: "回显请求体") { request in
                    struct Payload: Decodable { let text: String }
                    let payload = try request.decodeBodyOrThrow(Payload.self)
                    return try .api(["text": payload.text] as [String: String])
                }
                .build(),
            forPlugin: "com.test.smoke"
        )

        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        // 路径参数
        let echoURL = URL(string: "http://127.0.0.1:\(port)/api/v1/smoke/echo/abc123")!
        let (echoData, echoResponse) = try await URLSession.shared.data(
            for: URLRequest(url: echoURL)
        )
        XCTAssertEqual((echoResponse as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue(String(data: echoData, encoding: .utf8)?.contains("abc123") ?? false)

        // 查询参数
        let queryURL = URL(string: "http://127.0.0.1:\(port)/api/v1/smoke/query?name=hello")!
        let (queryData, _) = try await URLSession.shared.data(for: URLRequest(url: queryURL))
        XCTAssertTrue(String(data: queryData, encoding: .utf8)?.contains("hello") ?? false)

        // 请求体
        var bodyRequest = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/api/v1/smoke/body")!)
        bodyRequest.httpMethod = "POST"
        bodyRequest.httpBody = Data(#"{"text":"payload-value"}"#.utf8)
        let (bodyData, bodyResponse) = try await URLSession.shared.data(for: bodyRequest)
        XCTAssertEqual((bodyResponse as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue(String(data: bodyData, encoding: .utf8)?.contains("payload-value") ?? false)
    }

    /// 自描述端点列出所有已注册路由，便于外部调用方发现能力。
    func testDiscoveryEndpointListsRegisteredRoutes() async throws {
        let server = LumiWebServer(port: 0)
        server.register(
            WebRouteBuilder(prefix: "smoke")
                .get("/api/v1/smoke/a") { _ in .text("a") }
                .build(),
            forPlugin: "com.test.smoke"
        )

        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        let url = URL(string: "http://127.0.0.1:\(port)/api/plugins")!
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))

        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)

        struct Discovery: Decodable {
            struct RouteInfo: Decodable {
                let plugin: String
                let id: String
                let method: String
                let path: String
            }
            let routes: [RouteInfo]
        }
        let decoded = try JSONDecoder().decode(Discovery.self, from: data)
        XCTAssertTrue(decoded.routes.contains { $0.path == "/api/v1/smoke/a" })
        XCTAssertTrue(decoded.routes.contains { $0.plugin == "com.test.smoke" })
    }

    /// 插件注销后其端点立即不可达。
    func testUnregisteredRoutesBecomeUnreachable() async throws {
        let server = LumiWebServer(port: 0)
        server.register(
            [WebRoute(id: "ping", method: .get, path: "/ping") { _ in .text("pong") }],
            forPlugin: "com.test.plugin"
        )

        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        let url = URL(string: "http://127.0.0.1:\(port)/ping")!
        let (_, beforeResponse) = try await URLSession.shared.data(for: URLRequest(url: url))
        XCTAssertEqual((beforeResponse as? HTTPURLResponse)?.statusCode, 200)

        server.unregister(pluginID: "com.test.plugin")

        let (_, afterResponse) = try await URLSession.shared.data(for: URLRequest(url: url))
        XCTAssertEqual((afterResponse as? HTTPURLResponse)?.statusCode, 404)
    }
}
