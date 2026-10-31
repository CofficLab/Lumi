import Foundation
import Testing
@testable import PluginLLMProviderMiniMax

/// `TokenPlanService.processResponse` 的解析行为。
///
/// 覆盖 `/v1/token_plan/remains` 的正常响应、业务状态码异常、字段缺失三类路径，
/// 以及毫秒/秒单位换算。
@Suite("TokenPlanService 解析")
struct TokenPlanServiceParsingTests {

    // MARK: - 正常响应

    @Test("解析 model_remains 全部字段")
    func parsesAllFields() throws {
        let data = Self.payload(
            """
            {"base_resp":{"status_code":0,"status_msg":"success"},
             "model_remains":[{
               "model_name":"general",
               "current_interval_remaining_percent":81,
               "current_interval_status":1,
               "current_interval_total_count":100,
               "current_interval_usage_count":19,
               "start_time":1788000000000,
               "end_time":1788018000000,
               "remains_time":12345000,
               "current_weekly_remaining_percent":98,
               "current_weekly_status":1,
               "current_weekly_total_count":500,
               "current_weekly_usage_count":10,
               "weekly_start_time":1787500000000,
               "weekly_end_time":1788100000000,
               "weekly_remains_time":345600000
             }]}
            """
        )

        let status = TokenPlanService.processResponse(data: data)

        let plans = try #require(Self.plans(from: status))
        #expect(plans.count == 1)
        let plan = plans[0]
        #expect(plan.modelName == "general")
        #expect(plan.remainingPercent == 81)
        #expect(plan.intervalStatus == 1)
        #expect(plan.intervalTotal == 100)
        #expect(plan.intervalUsage == 19)
        #expect(plan.startTime == 1_788_000_000_000)
        #expect(plan.endTime == 1_788_018_000_000)
        #expect(plan.weeklyRemainingPercent == 98)
        #expect(plan.weeklyTotal == 500)
        #expect(plan.weeklyUsage == 10)
    }

    @Test("毫秒剩余时间换算为秒")
    func convertsMillisecondsToSeconds() throws {
        // remains_time = 12345000ms → 12345s；weekly_remains_time = 345600000ms → 345600s
        let data = Self.payload(
            """
            {"base_resp":{"status_code":0},
             "model_remains":[{
               "model_name":"general","remains_time":12345000,"weekly_remains_time":345600000
             }]}
            """
        )

        let plans = try #require(Self.plans(from: TokenPlanService.processResponse(data: data)))
        #expect(plans[0].remainsTime == 12_345)
        #expect(plans[0].weeklyRemainsTime == 345_600)
    }

    @Test("缺失的计数字段回落为 0")
    func missingNumericFieldsDefaultToZero() throws {
        let data = Self.payload(
            """
            {"model_remains":[{"model_name":"video"}]}
            """
        )

        let plans = try #require(Self.plans(from: TokenPlanService.processResponse(data: data)))
        let plan = plans[0]
        #expect(plan.remainingPercent == 0)
        #expect(plan.intervalTotal == 0)
        #expect(plan.weeklyRemainingPercent == 0)
        #expect(plan.remainsTime == 0)
    }

    @Test("多模型按数组顺序保留")
    func preservesMultipleModels() throws {
        let data = Self.payload(
            """
            {"model_remains":[
              {"model_name":"general","current_interval_remaining_percent":81},
              {"model_name":"video","current_interval_total_count":20,"current_interval_usage_count":20}
            ]}
            """
        )

        let plans = try #require(Self.plans(from: TokenPlanService.processResponse(data: data)))
        #expect(plans.map(\.modelName) == ["general", "video"])
    }

    // MARK: - 异常响应

    @Test("缺少 model_name 的条目被丢弃")
    func dropsEntriesWithoutModelName() {
        let data = Self.payload(
            """
            {"model_remains":[{"current_interval_remaining_percent":50},{"model_name":"general"}]}
            """
        )

        // 还有一条合法条目，整体仍视为成功。
        let plans = Self.plans(from: TokenPlanService.processResponse(data: data))
        #expect(plans?.map(\.modelName) == ["general"])
    }

    @Test("全部条目缺 model_name 时视为不可用")
    func unavailableWhenAllEntriesLackModelName() {
        let data = Self.payload(#"{"model_remains":[{"foo":1}]}"#)

        #expect(TokenPlanService.processResponse(data: data) == .unavailable)
    }

    @Test("业务认证错误码映射为 authError")
    func businessAuthStatusMapsToAuthError() {
        for code in [1001, 1002] {
            let data = Self.payload(
                #"{"base_resp":{"status_code":\#(code),"status_msg":"invalid key"},"model_remains":[]}"#
            )
            #expect(TokenPlanService.processResponse(data: data) == .authError)
        }
    }

    @Test("其它业务错误码映射为 unavailable")
    func otherBusinessStatusMapsToUnavailable() {
        let data = Self.payload(
            #"{"base_resp":{"status_code":2001,"status_msg":"quota exhausted"},"model_remains":[]}"#
        )

        #expect(TokenPlanService.processResponse(data: data) == .unavailable)
    }

    @Test("缺少 model_remains 字段视为不可用")
    func missingModelRemainsIsUnavailable() {
        let data = Self.payload(#"{"base_resp":{"status_code":0}}"#)

        #expect(TokenPlanService.processResponse(data: data) == .unavailable)
    }

    @Test("空 model_remains 数组视为不可用")
    func emptyModelRemainsIsUnavailable() {
        let data = Self.payload(#"{"model_remains":[]}"#)

        #expect(TokenPlanService.processResponse(data: data) == .unavailable)
    }

    @Test("非 JSON 响应视为不可用")
    func invalidJSONIsUnavailable() {
        let data = Data("<html>502 Bad Gateway</html>".utf8)

        #expect(TokenPlanService.processResponse(data: data) == .unavailable)
    }

    @Test("base_resp 缺失时仍按 status_code 0 处理")
    func missingBaseRespTreatedAsSuccess() throws {
        let data = Self.payload(#"{"model_remains":[{"model_name":"general"}]}"#)

        let plans = try #require(Self.plans(from: TokenPlanService.processResponse(data: data)))
        #expect(plans.count == 1)
    }

    // MARK: - Helpers

    private static func payload(_ json: String) -> Data {
        Data(json.utf8)
    }

    private static func plans(from status: TokenPlanStatus) -> [TokenPlanData]? {
        guard case let .success(plans) = status else { return nil }
        return plans
    }
}
