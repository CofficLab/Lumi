import Foundation
import Testing
@testable import ProviderWebServer

// MARK: - API Error Tests

@Suite("WebAPIError")
struct WebAPIErrorTests {
    @Test("每个错误映射到约定的状态码")
    func mapsToStatusCodes() {
        #expect(WebAPIError.badRequest(message: "x").statusCode == 400)
        #expect(WebAPIError.unauthorized().statusCode == 401)
        #expect(WebAPIError.forbidden(message: "x").statusCode == 403)
        #expect(WebAPIError.notFound().statusCode == 404)
        #expect(WebAPIError.methodNotAllowed().statusCode == 405)
        #expect(WebAPIError.conflict(message: "x").statusCode == 409)
        #expect(WebAPIError.payloadTooLarge().statusCode == 413)
        #expect(WebAPIError.unsupportedMediaType().statusCode == 415)
        #expect(WebAPIError.internalError().statusCode == 500)
        #expect(WebAPIError.unavailable().statusCode == 503)
        #expect(WebAPIError.timeout().statusCode == 504)
    }

    @Test("错误码是稳定的机器可读字符串")
    func hasStableCodes() {
        #expect(WebAPIError.badRequest(message: "x").code == "bad_request")
        #expect(WebAPIError.unauthorized().code == "unauthorized")
        #expect(WebAPIError.notFound().code == "not_found")
        #expect(WebAPIError.internalError().code == "internal_error")
    }

    @Test("只有 badRequest 携带字段名")
    func fieldOnlyOnBadRequest() {
        #expect(WebAPIError.badRequest(message: "x", field: "name").field == "name")
        #expect(WebAPIError.notFound().field == nil)
        #expect(WebAPIError.internalError().field == nil)
    }

    @Test("错误体编码为统一形状")
    func encodesErrorBody() throws {
        let response = WebErrorResponse(
            .badRequest(message: "missing field", field: "name"),
            requestID: "req-1"
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(WebErrorResponse.self, from: data)

        #expect(decoded.error.code == "bad_request")
        #expect(decoded.error.message == "missing field")
        #expect(decoded.error.field == "name")
        #expect(decoded.error.requestID == "req-1")
    }

    @Test("成功信封携带 data 与版本")
    func encodesEnvelope() throws {
        struct Payload: Codable, Equatable { let value: Int }
        let envelope = WebAPIEnvelope(
            data: Payload(value: 7),
            requestID: "req-2",
            version: .v1
        )
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(WebAPIDecodableEnvelope<Payload>.self, from: data)

        #expect(decoded.data == Payload(value: 7))
        #expect(decoded.requestID == "req-2")
        #expect(decoded.version == "v1")
    }
}

// MARK: - Auth Tests

@Suite("WebAuthPolicy")
struct WebAuthPolicyTests {
    @Test("强制鉴权时缺少凭证被拒绝")
    func rejectsMissingCredentials() {
        let policy = WebAuthPolicy.required
        #expect(policy.validate(headers: [:]) != nil)
    }

    @Test("允许匿名时缺少凭证通过")
    func allowsAnonymous() {
        let policy = WebAuthPolicy.optional
        #expect(policy.validate(headers: [:]) == nil)
    }

    @Test("Bearer 凭证被正确提取")
    func extractsBearerToken() {
        let headers = ["authorization": "Bearer secret"]
        #expect(WebAuthScheme.bearer.credential(in: headers) == "secret")
    }

    @Test("兼容不带 Bearer 前缀的裸 token")
    func acceptsBareToken() {
        let headers = ["authorization": "secret"]
        #expect(WebAuthScheme.bearer.credential(in: headers) == "secret")
    }

    @Test("API Key 从 X-API-Key 头提取")
    func extractsAPIKey() {
        let headers = ["x-api-key": "key123"]
        #expect(WebAuthScheme.apiKey.credential(in: headers) == "key123")
    }

    @Test("允许匿名时错误凭证仍被拒绝")
    func rejectsWrongCredentialsEvenWhenAnonymousAllowed() {
        var store = WebCredentialStore()
        store.add("right", for: .bearer)
        let policy = store.policy(schemes: [.bearer], allowsAnonymous: true)

        #expect(policy.validate(headers: ["authorization": "Bearer wrong"]) != nil)
        #expect(policy.validate(headers: ["authorization": "Bearer right"]) == nil)
    }

    @Test("没有校验器时任何凭证都不通过")
    func rejectsWithoutVerifier() {
        let policy = WebAuthPolicy.required
        #expect(policy.validate(headers: ["authorization": "Bearer anything"]) != nil)
    }

    @Test("策略相等性只看方案与匿名标志")
    func equalityIgnoresVerifier() {
        var store = WebCredentialStore()
        store.add("token", for: .bearer)
        let withVerifier = store.policy(schemes: [.bearer], allowsAnonymous: false)
        let withoutVerifier = WebAuthPolicy(schemes: [.bearer], allowsAnonymous: false)

        #expect(withVerifier == withoutVerifier)
    }

    @Test("凭证存储支持多把 key 轮换")
    func supportsMultipleCredentials() {
        var store = WebCredentialStore()
        store.add("old", for: .bearer)
        store.add("new", for: .bearer)

        #expect(store.validate("old", for: .bearer))
        #expect(store.validate("new", for: .bearer))
        #expect(!store.validate("other", for: .bearer))
    }

    @Test("移除凭证后立即失效")
    func removesCredentials() {
        var store = WebCredentialStore()
        store.add("token", for: .bearer)
        store.remove("token", for: .bearer)

        #expect(!store.validate("token", for: .bearer))
    }

    @Test("API Key 方案也可用")
    func supportsAPIKeyScheme() {
        var store = WebCredentialStore()
        store.add("key", for: .apiKey)
        let policy = store.policy(schemes: [.apiKey], allowsAnonymous: false)

        #expect(policy.validate(headers: ["x-api-key": "key"]) == nil)
        #expect(policy.validate(headers: ["x-api-key": "bad"]) != nil)
    }
}

// MARK: - Pagination Tests

@Suite("WebPagination")
struct WebPaginationTests {
    @Test("默认分页参数")
    func defaults() {
        let pagination = WebPagination()
        #expect(pagination.offset == 0)
        #expect(pagination.limit == WebPagination.defaultLimit)
    }

    @Test("从查询参数解析 offset 与 limit")
    func parsesQuery() {
        let pagination = WebPagination(query: ["offset": "10", "limit": "5"])
        #expect(pagination.offset == 10)
        #expect(pagination.limit == 5)
    }

    @Test("支持 page 与 pageSize 风格")
    func parsesPageStyle() {
        let pagination = WebPagination(query: ["page": "3", "pageSize": "20"])
        #expect(pagination.offset == 40)
        #expect(pagination.limit == 20)
    }

    @Test("非法参数回退到默认值而非报错")
    func fallsBackOnInvalidInput() {
        let pagination = WebPagination(query: ["offset": "abc", "limit": "-3"])
        #expect(pagination.offset == 0)
        #expect(pagination.limit == WebPagination.defaultLimit)
    }

    @Test("超出上限的 limit 被截断")
    func clampsLimit() {
        let pagination = WebPagination(query: ["limit": "100000"])
        #expect(pagination.limit == WebPagination.maxLimit)
    }

    @Test("分页返回正确切片")
    func pagesItems() {
        let items = Array(0..<10)
        let page = WebPagination(offset: 3, limit: 4).page(of: items)
        #expect(page == [3, 4, 5, 6])
    }

    @Test("偏移越界返回空数组")
    func returnsEmptyWhenOutOfRange() {
        let page = WebPagination(offset: 100, limit: 10).page(of: Array(0..<5))
        #expect(page.isEmpty)
    }

    @Test("分页结果携带总数与是否还有下一页")
    func buildsPageResult() {
        let result = WebPageResult(items: Array(0..<10), pagination: WebPagination(offset: 0, limit: 3))
        #expect(result.items.count == 3)
        #expect(result.total == 10)
        #expect(result.hasMore == true)
    }

    @Test("最后一页没有更多数据")
    func reportsNoMorePages() {
        let result = WebPageResult(items: Array(0..<10), pagination: WebPagination(offset: 9, limit: 3))
        #expect(result.items.count == 1)
        #expect(result.hasMore == false)
    }
}

// MARK: - Request Log Tests

@Suite("请求日志")
struct WebRequestLogTests {
    @Test("内存日志按最新在前记录")
    func recordsNewestFirst() {
        let sink = WebInMemoryRequestLogSink()
        sink.record(WebRequestLog(requestID: "1", method: "GET", path: "/a", statusCode: 200, duration: 0.1))
        sink.record(WebRequestLog(requestID: "2", method: "POST", path: "/b", statusCode: 201, duration: 0.2))

        #expect(sink.count == 2)
        #expect(sink.recentLogs.first?.requestID == "2")
    }

    @Test("超出容量时丢弃最旧记录")
    func trimsOldest() {
        let sink = WebInMemoryRequestLogSink(capacity: 2)
        for index in 0..<5 {
            sink.record(
                WebRequestLog(
                    requestID: "\(index)",
                    method: "GET",
                    path: "/a",
                    statusCode: 200,
                    duration: 0.1
                )
            )
        }

        #expect(sink.count == 2)
        #expect(sink.recentLogs.first?.requestID == "4")
    }

    @Test("清空后无记录")
    func clearsLogs() {
        let sink = WebInMemoryRequestLogSink()
        sink.record(WebRequestLog(requestID: "1", method: "GET", path: "/a", statusCode: 200, duration: 0.1))
        sink.clear()

        #expect(sink.count == 0)
    }
}

// MARK: - CORS Tests

@Suite("WebCORSPolicy")
struct WebCORSPolicyTests {
    @Test("通配来源允许任意 origin")
    func allowsAnyOrigin() {
        let policy = WebCORSPolicy()
        #expect(policy.allowedOrigin(in: "http://example.com") == "*")
    }

    @Test("指定来源时只回显匹配的那个")
    func echoesMatchingOrigin() {
        let policy = WebCORSPolicy(allowedOrigins: ["http://a.com", "http://b.com"])
        #expect(policy.allowedOrigin(in: "http://b.com") == "http://b.com")
        #expect(policy.allowedOrigin(in: "http://evil.com") == nil)
    }

    @Test("缺少 Origin 头时不返回来源")
    func requiresOriginHeader() {
        let policy = WebCORSPolicy()
        #expect(policy.allowedOrigin(in: nil) == nil)
    }

    @Test("允许凭据时回显具体来源而非通配")
    func echoesConcreteOriginWithCredentials() {
        let policy = WebCORSPolicy(allowedOrigins: ["*"], allowsCredentials: true)
        #expect(policy.allowedOrigin(in: "http://example.com") == "http://example.com")
    }
}

// MARK: - Route Builder Tests

@Suite("WebRouteBuilder")
struct WebRouteBuilderTests {
    @Test("构建出声明的路由")
    func buildsRoutes() {
        let routes = WebRouteBuilder(prefix: "test")
            .get("/api/v1/test/a", description: "A") { _ in .text("a") }
            .post("/api/v1/test/b") { _ in .text("b") }
            .build()

        #expect(routes.count == 2)
        #expect(routes[0].method == .get)
        #expect(routes[0].path == "/api/v1/test/a")
        #expect(routes[0].description == "A")
        #expect(routes[1].method == .post)
    }

    @Test("生成的路由 id 稳定且含方法与路径")
    func generatesStableIDs() {
        let routes = WebRouteBuilder(prefix: "my-plugin")
            .get("/api/v1/my-plugin/items/:id") { _ in .text("x") }
            .build()

        #expect(routes[0].id == "my-plugin.get.api-v1-my-plugin-items-by-id")
    }

    @Test("相同声明生成相同 id")
    func isDeterministic() {
        let first = WebRouteBuilder(prefix: "p").get("/a/:id") { _ in .text("x") }.build()
        let second = WebRouteBuilder(prefix: "p").get("/a/:id") { _ in .text("y") }.build()

        #expect(first[0].id == second[0].id)
    }

    @Test("空前缀回退到默认名")
    func fallsBackToDefaultPrefix() {
        let routes = WebRouteBuilder(prefix: "").get("/a") { _ in .text("x") }.build()
        #expect(routes[0].id == "route.get.a")
    }
}

// MARK: - Route Request Tests

@Suite("WebRouteRequest")
struct WebRouteRequestTests {
    @Test("解码 JSON 请求体")
    func decodesBody() throws {
        struct Payload: Decodable { let name: String }
        let data = Data(#"{"name":"lumi"}"#.utf8)
        let request = WebRouteRequest(method: .post, path: "/x", body: data)

        let payload = try request.decodeBody(as: Payload.self)
        #expect(payload.name == "lumi")
    }

    @Test("非法 JSON 抛出统一的 badRequest")
    func throwsBadRequestOnInvalidJSON() {
        struct Payload: Decodable { let name: String }
        let request = WebRouteRequest(method: .post, path: "/x", body: Data("not json".utf8))

        #expect(throws: WebAPIError.self) {
            try request.decodeBodyOrThrow(Payload.self)
        }
    }

    @Test("空请求体抛出 badRequest")
    func throwsBadRequestOnEmptyBody() {
        struct Payload: Decodable { let name: String }
        let request = WebRouteRequest(method: .post, path: "/x")

        #expect(throws: WebAPIError.self) {
            try request.decodeBodyOrThrow(Payload.self)
        }
    }

    @Test("缺少必需路径参数抛出 badRequest")
    func throwsBadRequestOnMissingPathParameter() {
        let request = WebRouteRequest(method: .get, path: "/x")

        #expect(throws: WebAPIError.self) {
            try request.requirePathParameter("id")
        }
    }

    @Test("缺少必需查询参数抛出 badRequest")
    func throwsBadRequestOnMissingQueryParameter() {
        let request = WebRouteRequest(method: .get, path: "/x")

        #expect(throws: WebAPIError.self) {
            try request.requireQueryParameter("q")
        }
    }

    @Test("从查询参数解析分页")
    func exposesPagination() {
        let request = WebRouteRequest(
            method: .get,
            path: "/x",
            queryParameters: ["offset": "5", "limit": "10"]
        )
        #expect(request.pagination.offset == 5)
        #expect(request.pagination.limit == 10)
    }
}

// MARK: - Route Registry Tests

@Suite("WebRouteRegistry")
struct WebRouteRegistryTests {
    @Test("注册与注销路由")
    func registersAndUnregisters() {
        let registry = WebRouteRegistry()
        registry.register([WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }], forPlugin: "p")

        #expect(registry.routeCount == 1)
        #expect(registry.pluginIDs == ["p"])

        registry.unregister(pluginID: "p")
        #expect(registry.routeCount == 0)
    }

    @Test("同一插件重复注册整体替换")
    func replacesOnSecondRegistration() {
        let registry = WebRouteRegistry()
        registry.register([WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }], forPlugin: "p")
        registry.register([WebRoute(id: "b", method: .get, path: "/b") { _ in .text("b") }], forPlugin: "p")

        #expect(registry.routeCount == 1)
        #expect(registry.snapshot().first?.route.id == "b")
    }

    @Test("注册空数组等效于注销")
    func emptyRegistrationUnregisters() {
        let registry = WebRouteRegistry()
        registry.register([WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }], forPlugin: "p")
        registry.register([], forPlugin: "p")

        #expect(registry.routeCount == 0)
    }

    @Test("摘要包含归属插件与方法路径")
    func buildsSummaries() {
        let registry = WebRouteRegistry()
        registry.register(
            [WebRoute(id: "a", method: .post, path: "/a/:id", description: "A") { _ in .text("a") }],
            forPlugin: "p"
        )

        let summary = registry.summaries()[0]
        #expect(summary.pluginID == "p")
        #expect(summary.routeID == "a")
        #expect(summary.method == "POST")
        #expect(summary.path == "/a/:id")
        #expect(summary.description == "A")
    }
}
