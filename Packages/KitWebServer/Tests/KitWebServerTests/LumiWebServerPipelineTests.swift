import Foundation
import XCTest
import ProviderWebServer
@testable import KitWebServer

/// 覆盖 HTTP 层的请求处理管线：鉴权、请求 ID、错误映射、请求日志、CORS。
final class LumiWebServerPipelineTests: XCTestCase {
    // MARK: - 鉴权

    /// 开启鉴权时，未携带凭证的请求返回 401 且不进入路由匹配。
    func testAuthRejectsBeforeRouteMatching() async throws {
        let server = LumiWebServer(port: 0, authToken: "s3cret")
        server.register([
            WebRoute(id: "ping", method: .get, path: "/ping") { _ in .text("pong") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        let url = URL(string: "http://127.0.0.1:\(port)/ping")!
        let (_, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.statusCode, 401)
        // 错误体是统一 JSON 形状。
        XCTAssertEqual(http.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    /// 鉴权失败时返回统一错误体，含机器可读错误码。
    func testAuthErrorBodyIsUnified() async throws {
        let server = LumiWebServer(port: 0, authToken: "s3cret")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        let url = URL(string: "http://127.0.0.1:\(port)/anything")!
        let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))

        struct ErrorEnvelope: Decodable {
            struct Body: Decodable {
                let code: String
                let message: String
                let requestID: String?
            }
            let error: Body
        }
        let decoded = try JSONDecoder().decode(ErrorEnvelope.self, from: data)
        XCTAssertEqual(decoded.error.code, "unauthorized")
        XCTAssertNotNil(decoded.error.requestID)
    }

    /// 允许匿名访问时，未携带凭证的请求正常放行。
    func testAnonymousAccessAllowed() async throws {
        let server = LumiWebServer(port: 0)
        server.setAuthPolicy(.optional)
        server.register([
            WebRoute(id: "ping", method: .get, path: "/ping") { _ in .text("pong") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        let url = URL(string: "http://127.0.0.1:\(port)/ping")!
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), "pong")
    }

    // MARK: - 请求 ID

    /// 响应头带 X-Request-ID。
    func testResponseCarriesRequestID() async throws {
        let server = LumiWebServer(port: 0)
        server.register([
            WebRoute(id: "ping", method: .get, path: "/ping") { _ in .text("pong") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        let url = URL(string: "http://127.0.0.1:\(port)/ping")!
        let (_, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        let requestID = http.value(forHTTPHeaderField: "X-Request-ID")
        XCTAssertNotNil(requestID)
        XCTAssertFalse(requestID?.isEmpty ?? true)
    }

    /// 调用方提供的 X-Request-ID 被透传到响应头。
    func testRequestIDIsPassedThrough() async throws {
        let server = LumiWebServer(port: 0)
        server.register([
            WebRoute(id: "ping", method: .get, path: "/ping") { _ in .text("pong") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ping")!)
        request.setValue("trace-abc", forHTTPHeaderField: "X-Request-ID")
        let (_, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.value(forHTTPHeaderField: "X-Request-ID"), "trace-abc")
    }

    // MARK: - 错误映射

    /// 处理器抛出 WebAPIError 时，服务端映射为对应状态码与统一错误体。
    func testAPIErrorMapsToStatusCode() async throws {
        let server = LumiWebServer(port: 0)
        server.register([
            WebRoute(id: "boom", method: .get, path: "/boom") { _ in
                throw WebAPIError.conflict(message: "already exists")
            },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        let url = URL(string: "http://127.0.0.1:\(port)/boom")!
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.statusCode, 409)

        struct ErrorEnvelope: Decodable {
            struct Body: Decodable {
                let code: String
                let message: String
            }
            let error: Body
        }
        let decoded = try JSONDecoder().decode(ErrorEnvelope.self, from: data)
        XCTAssertEqual(decoded.error.code, "conflict")
        XCTAssertEqual(decoded.error.message, "already exists")
    }

    /// 未识别的错误按 500 处理，且不回显内部细节。
    func testUnknownErrorBecomesGenericInternalError() async throws {
        let server = LumiWebServer(port: 0)
        server.register([
            WebRoute(id: "boom", method: .get, path: "/boom") { _ in
                throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "secret path /etc/passwd"])
            },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        let url = URL(string: "http://127.0.0.1:\(port)/boom")!
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.statusCode, 500)
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(text.contains("/etc/passwd"))
    }

    /// 路径存在但方法不符时返回 405 而非 404。
    func testMethodMismatchReturns405() async throws {
        let server = LumiWebServer(port: 0)
        server.register([
            WebRoute(id: "only-post", method: .post, path: "/only-post") { _ in .text("ok") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        let url = URL(string: "http://127.0.0.1:\(port)/only-post")!
        let (_, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.statusCode, 405)
    }

    /// 未匹配路径返回 404 与统一错误体。
    func testNotFoundReturnsUnifiedError() async throws {
        let server = LumiWebServer(port: 0)
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        let url = URL(string: "http://127.0.0.1:\(port)/nope")!
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.statusCode, 404)

        struct ErrorEnvelope: Decodable {
            struct Body: Decodable { let code: String }
            let error: Body
        }
        let decoded = try JSONDecoder().decode(ErrorEnvelope.self, from: data)
        XCTAssertEqual(decoded.error.code, "not_found")
    }

    // MARK: - 请求日志

    /// 请求完成后写入请求日志，含方法、路径与状态码。
    func testRequestLogRecordsRequest() async throws {
        let sink = WebInMemoryRequestLogSink()
        let server = LumiWebServer(port: 0)
        server.setRequestLogSink(sink)
        server.register([
            WebRoute(id: "ping", method: .get, path: "/ping") { _ in .text("pong") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        let url = URL(string: "http://127.0.0.1:\(port)/ping")!
        _ = try await URLSession.shared.data(for: URLRequest(url: url))

        XCTAssertEqual(sink.count, 1)
        let log = try XCTUnwrap(sink.recentLogs.first)
        XCTAssertEqual(log.method, "GET")
        XCTAssertEqual(log.path, "/ping")
        XCTAssertEqual(log.statusCode, 200)
        XCTAssertEqual(log.pluginID, "com.test.plugin")
        XCTAssertFalse(log.requestID.isEmpty)
    }

    /// 失败请求同样被记录，状态码如实反映。
    func testRequestLogRecordsFailures() async throws {
        let sink = WebInMemoryRequestLogSink()
        let server = LumiWebServer(port: 0)
        server.setRequestLogSink(sink)
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        let url = URL(string: "http://127.0.0.1:\(port)/missing")!
        _ = try await URLSession.shared.data(for: URLRequest(url: url))

        XCTAssertEqual(sink.count, 1)
        XCTAssertEqual(sink.recentLogs.first?.statusCode, 404)
    }

    /// 请求日志不含请求体——请求体可能含敏感数据。
    func testRequestLogDoesNotLeakBody() async throws {
        let sink = WebInMemoryRequestLogSink()
        let server = LumiWebServer(port: 0)
        server.setRequestLogSink(sink)
        server.register([
            WebRoute(id: "echo", method: .post, path: "/echo") { _ in .text("ok") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/echo")!)
        request.httpMethod = "POST"
        request.httpBody = Data("super-secret-token".utf8)
        _ = try await URLSession.shared.data(for: request)

        let log = try XCTUnwrap(sink.recentLogs.first)
        XCTAssertFalse(log.path.contains("super-secret-token"))
        XCTAssertEqual(log.path, "/echo")
    }

    // MARK: - CORS

    /// 预检请求返回允许的方法与请求头。
    func testCORSPreflightResponse() async throws {
        let server = LumiWebServer(port: 0, corsPolicy: WebCORSPolicy())
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/anything")!)
        request.httpMethod = "OPTIONS"
        request.setValue("http://example.com", forHTTPHeaderField: "Origin")
        let (_, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.statusCode, 204)
        XCTAssertEqual(http.value(forHTTPHeaderField: "Access-Control-Allow-Origin"), "*")
        XCTAssertNotNil(http.value(forHTTPHeaderField: "Access-Control-Allow-Methods"))
    }

    /// 不在白名单的来源不会得到 CORS 允许头。
    func testCORSRejectsUnlistedOrigin() async throws {
        let server = LumiWebServer(
            port: 0,
            corsPolicy: WebCORSPolicy(allowedOrigins: ["http://allowed.com"])
        )
        server.register([
            WebRoute(id: "ping", method: .get, path: "/ping") { _ in .text("pong") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ping")!)
        request.setValue("http://evil.com", forHTTPHeaderField: "Origin")
        let (_, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertNil(http.value(forHTTPHeaderField: "Access-Control-Allow-Origin"))
    }

    // MARK: - 跨源写保护

    /// 跨源表单 POST 在进入路由前被拒绝（CORS 不返回响应头不足以阻止送达）。
    func testCrossOriginWriteRejectedBeforeRoute() async throws {
        let server = LumiWebServer(port: 0)
        server.register([
            WebRoute(id: "select", method: .post, path: "/state") { _ in .text("executed") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/state")!)
        request.httpMethod = "POST"
        request.setValue("http://evil.example", forHTTPHeaderField: "Origin")
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.statusCode, 403)

        struct ErrorEnvelope: Decodable {
            struct Body: Decodable { let code: String }
            let error: Body
        }
        let decoded = try JSONDecoder().decode(ErrorEnvelope.self, from: data)
        XCTAssertEqual(decoded.error.code, "forbidden")
    }

    /// Fetch Metadata 标记为跨站时，即使没有 Origin 也拒绝。
    func testCrossSiteFetchMetadataRejected() async throws {
        let server = LumiWebServer(port: 0)
        server.register([
            WebRoute(id: "select", method: .post, path: "/state") { _ in .text("executed") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/state")!)
        request.httpMethod = "POST"
        request.setValue("cross-site", forHTTPHeaderField: "Sec-Fetch-Site")
        let (_, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.statusCode, 403)
    }

    /// 同源写请求正常执行。
    func testSameOriginWriteIsAllowed() async throws {
        let server = LumiWebServer(port: 0)
        server.register([
            WebRoute(id: "select", method: .post, path: "/state") { _ in .text("executed") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/state")!)
        request.httpMethod = "POST"
        request.setValue("http://127.0.0.1:\(port)", forHTTPHeaderField: "Origin")
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), "executed")
    }

    /// 没有 Origin 的非浏览器调用方（curl、原生客户端）保持可用。
    func testWriteWithoutOriginIsAllowed() async throws {
        let server = LumiWebServer(port: 0)
        server.register([
            WebRoute(id: "select", method: .post, path: "/state") { _ in .text("executed") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/state")!)
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), "executed")
    }

    /// 显式配置的 CORS 允许来源视为已授权，其写请求放行。
    func testCORSAllowlistedOriginWriteIsAllowed() async throws {
        let server = LumiWebServer(
            port: 0,
            corsPolicy: WebCORSPolicy(allowedOrigins: ["http://allowed.example"])
        )
        server.register([
            WebRoute(id: "select", method: .post, path: "/state") { _ in .text("executed") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/state")!)
        request.httpMethod = "POST"
        request.setValue("http://allowed.example", forHTTPHeaderField: "Origin")
        let (_, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.statusCode, 200)
    }

    /// 读请求不受跨源写保护影响。
    func testCrossOriginReadIsAllowed() async throws {
        let server = LumiWebServer(port: 0)
        server.register([
            WebRoute(id: "ping", method: .get, path: "/ping") { _ in .text("pong") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)
        defer { Task { await server.stop() } }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/ping")!)
        request.setValue("http://evil.example", forHTTPHeaderField: "Origin")
        let (_, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(http.statusCode, 200)
    }

    // MARK: - 其它

    /// 运行时长在服务启动后大于 0。
    func testUptimeReflectsRunningState() async throws {
        let server = LumiWebServer(port: 0)
        XCTAssertEqual(server.uptime, 0)

        try await server.start()
        defer { Task { await server.stop() } }

        XCTAssertGreaterThan(server.uptime, 0)
    }

    /// 已注册路由摘要包含归属插件、方法与路径。
    func testRegisteredRouteSummaries() async throws {
        let server = LumiWebServer(port: 0)
        server.register([
            WebRoute(id: "a", method: .get, path: "/a", description: "A") { _ in .text("a") },
        ], forPlugin: "com.test.plugin")

        let summaries = server.registeredRouteSummaries()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.pluginID, "com.test.plugin")
        XCTAssertEqual(summaries.first?.method, "GET")
        XCTAssertEqual(summaries.first?.path, "/a")
        XCTAssertEqual(summaries.first?.description, "A")
        XCTAssertEqual(server.registeredRouteCount, 1)
    }
}
