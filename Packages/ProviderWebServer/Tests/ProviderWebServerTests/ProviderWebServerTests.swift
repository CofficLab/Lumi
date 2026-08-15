import Foundation
import Testing
@testable import ProviderWebServer

/// WebServerProviding 协议与 WebRoute 模型的基础验证。
@Suite("ProviderWebServer")
@MainActor
struct ProviderWebServerTests {

    /// 测试用实现：验证协议可被任意实现注入。
    private final class MockWebServerProvider: WebServerProviding, @unchecked Sendable {
        let port = 0
        private(set) var isRunning = false
        private(set) var registered: [(routes: [WebRoute], pluginID: String)] = []
        private(set) var unregistered: [String] = []
        private(set) var startCount = 0
        private(set) var stopCount = 0

        func register(_ routes: [WebRoute], forPlugin pluginID: String) {
            registered.append((routes, pluginID))
        }

        func unregister(pluginID: String) {
            unregistered.append(pluginID)
        }

        func start() async throws {
            isRunning = true
            startCount += 1
        }

        func stop() async {
            isRunning = false
            stopCount += 1
        }
    }

    // MARK: - HTTPMethod

    @Test("HTTPMethod rawValue 与 HTTP 方法一致")
    func httpMethodRawValues() {
        #expect(HTTPMethod.get.rawValue == "GET")
        #expect(HTTPMethod.post.rawValue == "POST")
        #expect(HTTPMethod.put.rawValue == "PUT")
        #expect(HTTPMethod.patch.rawValue == "PATCH")
        #expect(HTTPMethod.delete.rawValue == "DELETE")
        #expect(HTTPMethod.head.rawValue == "HEAD")
        #expect(HTTPMethod.options.rawValue == "OPTIONS")
    }

    // MARK: - WebRouteRequest / WebRouteResponse

    @Test("WebRouteRequest 可构造并解码 JSON body")
    func requestDecodesBody() throws {
        struct Payload: Decodable {
            let name: String
        }
        let body = Data(#"{"name":"lumi"}"#.utf8)
        let request = WebRouteRequest(method: .post, path: "/api/x", body: body)

        #expect(request.method == .post)
        #expect(request.path == "/api/x")
        #expect(request.pathParameters.isEmpty)

        let payload = try request.decodeBody(as: Payload.self)
        #expect(payload.name == "lumi")
    }

    @Test("WebRouteResponse 工厂方法")
    func responseFactories() throws {
        let json = try WebRouteResponse.json(["a": 1])
        #expect(json.statusCode == 200)
        #expect(json.headers["Content-Type"] == "application/json")

        let text = WebRouteResponse.text("hi", statusCode: 201)
        #expect(text.statusCode == 201)
        #expect(text.headers["Content-Type"] == "text/plain; charset=utf-8")

        #expect(WebRouteResponse.notFound.statusCode == 404)
        #expect(WebRouteResponse.methodNotAllowed.statusCode == 405)
    }

    @Test("WebRoute 可创建并携带描述")
    func webRouteConstruction() {
        let route = WebRoute(id: "x", method: .get, path: "/x", description: "desc") { _ in
            .text("ok")
        }
        #expect(route.id == "x")
        #expect(route.method == .get)
        #expect(route.path == "/x")
        #expect(route.description == "desc")
    }

    // MARK: - Protocol Injectability

    @Test("WebServerProviding 可注册实现并通过协议访问")
    func providerAccessibleThroughProtocol() async throws {
        let provider = MockWebServerProvider()
        let resolved: any WebServerProviding = provider

        resolved.register([], forPlugin: "p1")
        #expect(provider.registered.count == 1)

        try await resolved.start()
        #expect(provider.isRunning)

        await resolved.stop()
        #expect(!provider.isRunning)

        resolved.unregister(pluginID: "p1")
        #expect(provider.unregistered == ["p1"])
    }
}
