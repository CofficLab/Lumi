import XCTest
import ProviderWebServer
@testable import KitWebServer

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

    /// 自描述端点 GET /api/plugins 返回所有已注册路由。
    func testDiscoveryEndpoint() async throws {
        let server = LumiWebServer(port: 0)
        server.register([
            WebRoute(id: "a", method: .get, path: "/x", description: "做 X") { _ in .text("x") },
            WebRoute(id: "b", method: .post, path: "/y/:id", description: nil) { _ in .text("y") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)

        let url = URL(string: "http://127.0.0.1:\(port)/api/plugins")!
        let (data, resp) = try await URLSession.shared.data(for: URLRequest(url: url))
        let http = try XCTUnwrap(resp as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200)

        // 结构化解码,规避 JSON 格式细节(如 `/` 转义)。
        struct DiscoveryBody: Decodable {
            struct RouteInfo: Decodable {
                let plugin: String
                let method: String
                let path: String
                let description: String?
            }
            let routes: [RouteInfo]
        }
        let decoded = try JSONDecoder().decode(DiscoveryBody.self, from: data)
        XCTAssertEqual(decoded.routes.count, 2)
        let byPath = Dictionary(uniqueKeysWithValues: decoded.routes.map { ($0.path, $0) })
        XCTAssertEqual(byPath["/x"]?.method, "GET")
        XCTAssertEqual(byPath["/y/:id"]?.method, "POST")
        XCTAssertEqual(byPath["/x"]?.plugin, "com.test.plugin")
        XCTAssertEqual(byPath["/x"]?.description, "做 X")
        XCTAssertNil(byPath["/y/:id"]?.description)

        await server.stop()
    }

    /// 开启鉴权时,自描述端点同样受保护。
    func testDiscoveryRequiresAuthWhenEnabled() async throws {
        let server = LumiWebServer(port: 0, authToken: "tok")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)

        let url = URL(string: "http://127.0.0.1:\(port)/api/plugins")!
        let (_, resp) = try await URLSession.shared.data(for: URLRequest(url: url))
        XCTAssertEqual((resp as? HTTPURLResponse)?.statusCode, 401)

        await server.stop()
    }

    /// onActivity 回调在请求成功后携带完整活动记录。
    func testOnActivityReportsRequest() async throws {
        let fired = expectation(description: "onActivity")
        let box = LockedBox<WebRequestActivity>()
        let server = LumiWebServer(port: 0, onActivity: { activity in
            box.set(activity)
            fired.fulfill()
        })
        server.register([
            WebRoute(id: "set", method: .post, path: "/set", description: "设置某值") { _ in .text("ok") },
        ], forPlugin: "com.test.plugin")
        try await server.start()
        let port = try XCTUnwrap(server.boundPort)

        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/set")!)
        req.httpMethod = "POST"
        _ = try await URLSession.shared.data(for: req)

        await fulfillment(of: [fired], timeout: 5)
        let activity = try XCTUnwrap(box.get())
        XCTAssertEqual(activity.pluginID, "com.test.plugin")
        XCTAssertEqual(activity.method, "POST")
        XCTAssertEqual(activity.path, "/set")
        XCTAssertEqual(activity.description, "设置某值")
        XCTAssertEqual(activity.statusCode, 200)
        XCTAssertTrue(activity.isMutation)
        XCTAssertTrue(activity.isSuccess)

        await server.stop()
    }
}

/// 线程安全的单值容器,用于在跨线程回调中捕获结果供断言。
private final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T?

    func set(_ value: T) {
        lock.lock()
        self.value = value
        lock.unlock()
    }

    func get() -> T? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
