import Foundation
import Testing
import KitLLM
@testable import PluginLLMProviderMiniMax

/// `TokenPlanService.fetchTokenPlan` 的网络链路与错误分类。
///
/// 与 `TokenPlanServiceParsingTests`（纯解析）互补：这里覆盖 async 传输、
/// Keychain 读取、HTTP 状态码与业务状态码到 `TokenPlanStatus` 的映射。
///
/// 每个用例用独立的 storageKey（见 ``TestKeychain``），因此可以安全并行。
@Suite("TokenPlanService 网络链路")
struct TokenPlanServiceFetchTests {

    // MARK: - 成功路径

    @Test("携带 Bearer Key 请求配额端点并解析成功")
    func fetchesWithBearerToken() async throws {
        let key = TestKeychain.uniqueKey("success")
        TestKeychain.set("test-key", forKey: key)
        defer { TestKeychain.set(nil, forKey: key) }

        let network = StubLLMNetwork(json: StubPayload.tokenPlanSuccess)
        let status = await TokenPlanService.fetchTokenPlan(
            apiService: VendorAPIService(networkProvider: network),
            apiKeyStorageKey: key
        )

        #expect(network.requestCount == 1)
        let request = try #require(network.lastRequest)
        #expect(request.url == "https://www.minimaxi.com/v1/token_plan/remains")
        #expect(request.method == "GET")
        #expect(request.authorization == "Bearer test-key")
        #expect(request.headers["Content-Type"] == "application/json")

        let plans = try #require(Self.plans(from: status))
        #expect(plans.count == 1)
        #expect(plans[0].modelName == "general")
        #expect(plans[0].remainingPercent == 81)
        #expect(plans[0].weeklyRemainingPercent == 98)
    }

    // MARK: - API Key 缺失

    @Test("API Key 为空时返回 authError 且不发请求")
    func missingAPIKeyReturnsAuthErrorWithoutRequest() async {
        let key = TestKeychain.uniqueKey("missing")
        // 不写入任何 Key，断言缺 Key 时不产生网络流量。
        TestKeychain.set(nil, forKey: key)

        let network = StubLLMNetwork(json: StubPayload.tokenPlanSuccess)
        let status = await TokenPlanService.fetchTokenPlan(
            apiService: VendorAPIService(networkProvider: network),
            apiKeyStorageKey: key
        )

        #expect(status == .authError)
        #expect(network.requestCount == 0)
    }

    @Test("storageKey 为空串时返回 authError")
    func emptyStorageKeyReturnsAuthError() async {
        let network = StubLLMNetwork(json: StubPayload.tokenPlanSuccess)
        let status = await TokenPlanService.fetchTokenPlan(
            apiService: VendorAPIService(networkProvider: network),
            apiKeyStorageKey: ""
        )

        #expect(status == .authError)
        #expect(network.requestCount == 0)
    }

    // MARK: - HTTP 错误

    @Test("HTTP 401/403 归类为 authError", arguments: [401, 403])
    func httpAuthStatusMapsToAuthError(statusCode: Int) async throws {
        let key = TestKeychain.uniqueKey("auth\(statusCode)")
        TestKeychain.set("test-key", forKey: key)
        defer { TestKeychain.set(nil, forKey: key) }

        let network = StubLLMNetwork.http(statusCode, body: "denied")
        let status = await TokenPlanService.fetchTokenPlan(
            apiService: VendorAPIService(networkProvider: network),
            apiKeyStorageKey: key
        )

        #expect(status == .authError)
    }

    @Test("其它 HTTP 错误归类为 unavailable", arguments: [400, 404, 500, 503])
    func otherHTTPStatusMapsToUnavailable(statusCode: Int) async throws {
        let key = TestKeychain.uniqueKey("http\(statusCode)")
        TestKeychain.set("test-key", forKey: key)
        defer { TestKeychain.set(nil, forKey: key) }

        let network = StubLLMNetwork.http(statusCode, body: "boom")
        let status = await TokenPlanService.fetchTokenPlan(
            apiService: VendorAPIService(networkProvider: network),
            apiKeyStorageKey: key
        )

        #expect(status == .unavailable)
    }

    @Test("传输抛错归类为 unavailable")
    func transportFailureMapsToUnavailable() async throws {
        let key = TestKeychain.uniqueKey("transport")
        TestKeychain.set("test-key", forKey: key)
        defer { TestKeychain.set(nil, forKey: key) }

        let network = StubLLMNetwork.failing(URLError(.notConnectedToInternet))
        let status = await TokenPlanService.fetchTokenPlan(
            apiService: VendorAPIService(networkProvider: network),
            apiKeyStorageKey: key
        )

        #expect(status == .unavailable)
    }

    // MARK: - 端到端错误响应

    @Test("业务认证码经完整链路映射为 authError")
    func businessAuthStatusOverTheWireMapsToAuthError() async throws {
        let key = TestKeychain.uniqueKey("businessAuth")
        TestKeychain.set("test-key", forKey: key)
        defer { TestKeychain.set(nil, forKey: key) }

        let body = #"{"base_resp":{"status_code":1001,"status_msg":"invalid key"},"model_remains":[]}"#
        let network = StubLLMNetwork(json: body)
        let status = await TokenPlanService.fetchTokenPlan(
            apiService: VendorAPIService(networkProvider: network),
            apiKeyStorageKey: key
        )

        #expect(status == .authError)
    }

    @Test("200 但返回错误页时归类为 unavailable")
    func htmlErrorPageMapsToUnavailable() async throws {
        let key = TestKeychain.uniqueKey("html")
        TestKeychain.set("test-key", forKey: key)
        defer { TestKeychain.set(nil, forKey: key) }

        let network = StubLLMNetwork(json: "<html>maintenance</html>")
        let status = await TokenPlanService.fetchTokenPlan(
            apiService: VendorAPIService(networkProvider: network),
            apiKeyStorageKey: key
        )

        #expect(status == .unavailable)
    }

    // MARK: - Helpers

    private static func plans(from status: TokenPlanStatus) -> [TokenPlanData]? {
        guard case let .success(plans) = status else { return nil }
        return plans
    }
}
