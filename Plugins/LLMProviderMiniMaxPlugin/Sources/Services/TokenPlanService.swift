import Foundation
import LLMKit
import LumiKernel
import SuperLogKit
import os

/// MiniMax Token Plan 配额服务
@MainActor
enum TokenPlanService: SuperLog {
    /// 请求超时时间（秒）
    private static let timeout: TimeInterval = 5.0

    /// 日志分类，遵循 com.coffic.lumi 子系统规范
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "minimax.tokenplan")

    /// 标识 emoji
    nonisolated static let emoji = "🎯"

    /// 调试开关：开启后会打印配额查询过程中的详细日志，便于定位「配额不可用」的原因。
    /// 正式发布时设为 `false`，排查问题时设为 `true`。
    nonisolated(unsafe) static var verbose: Bool = false

    /// 获取 Token Plan 配额
    static func fetchTokenPlan(network: (any NetworkProviding)? = nil) async -> TokenPlanStatus {
        guard let network else {
            return .unavailable
        }

        let tokenPlanURL = "https://www.minimaxi.com/v1/token_plan/remains"

        if Self.verbose { Self.logger.info("\(Self.t)开始查询 Token Plan 配额 url=\(tokenPlanURL)") }

        // 从 LumiAPIKeyTools 获取 API Key
        let apiKey = LumiAPIKeyTools.get(storageKey: MiniMaxTokenPlanProvider.info._apiKeyStorageKey)
        guard !apiKey.isEmpty else {
            if Self.verbose { Self.logger.warning("\(Self.t)API Key 为空，返回认证失败 storageKey=\(MiniMaxTokenPlanProvider.info._apiKeyStorageKey ?? "<nil>")") }
            return .authError
        }

        guard let url = URL(string: tokenPlanURL) else {
            if Self.verbose { Self.logger.error("\(Self.t)URL 非法，返回配额不可用 url=\(tokenPlanURL)") }
            return .unavailable
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = timeout

        do {
            let response = try await network.request(HTTPRequest(
                url: url,
                method: .get,
                headers: request.allHTTPHeaderFields ?? [:],
                timeout: timeout
            ))
            let data = response.body
            let statusCode = response.statusCode

            // 响应体日志、JSON 解析和模型构造都放到 utility 任务，避免网络返回后占用主线程。
            return await Task.detached(priority: .utility) {
                Self.processResponse(data: data, statusCode: statusCode)
            }.value

        } catch let error as HTTPNetworkError {
            if error.statusCode == 401 || error.statusCode == 403 {
                if Self.verbose { Self.logger.warning("\(Self.t)HTTP \(error.statusCode ?? 0)，返回认证失败") }
                return .authError
            }
            if Self.verbose {
                Self.logger.error("\(Self.t)HTTP 请求失败，返回配额不可用 error=\(String(describing: error))")
            }
            return .unavailable
        } catch {
            if Self.verbose { Self.logger.error("\(Self.t)未知错误，返回配额不可用 error=\(String(describing: error))") }
            return .unavailable
        }
    }

    /// 在后台处理响应，避免完整 body 日志和 JSONSerialization 运行在主线程。
    nonisolated private static func processResponse(data: Data, statusCode: Int) -> TokenPlanStatus {
        if Self.verbose {
            // 仅保留有限长度的预览，避免异常响应或错误页造成日志膨胀。
            let bodyPreview = String(data: data.prefix(4096), encoding: .utf8) ?? "<非 UTF-8 数据>"
            Self.logger.info("\(Self.t)收到响应 statusCode=\(statusCode) bytes=\(data.count) bodyPreview=\(bodyPreview)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if Self.verbose { Self.logger.error("\(Self.t)响应体不是合法 JSON，返回配额不可用 bytes=\(data.count)") }
            return .unavailable
        }

        // 解析 base_resp 中的状态码和消息
        let baseResp = json["base_resp"] as? [String: Any]
        let businessStatusCode = baseResp?["status_code"] as? Int ?? 0
        if businessStatusCode != 0 {
            let errorMessage = baseResp?["status_msg"] as? String ?? "未知错误"
            if businessStatusCode == 1001 || businessStatusCode == 1002 {
                if Self.verbose { Self.logger.warning("\(Self.t)业务状态码=\(businessStatusCode)，返回认证失败 message=\(errorMessage)") }
                return .authError
            }
            if Self.verbose { Self.logger.error("\(Self.t)业务状态码非 0，返回配额不可用 status_code=\(businessStatusCode) message=\(errorMessage)") }
            return .unavailable
        }

        guard let modelRemains = json["model_remains"] as? [[String: Any]], !modelRemains.isEmpty else {
            if Self.verbose { Self.logger.error("\(Self.t)响应缺少 model_remains 字段，返回配额不可用 keys=\(json.keys.joined(separator: ","))") }
            return .unavailable
        }

        let plans = modelRemains.compactMap { item -> TokenPlanData? in
            guard let modelName = item["model_name"] as? String else { return nil }
            return TokenPlanData(
                modelName: modelName,
                remainingPercent: item["current_interval_remaining_percent"] as? Int ?? 0,
                intervalStatus: item["current_interval_status"] as? Int ?? 0,
                intervalTotal: item["current_interval_total_count"] as? Int ?? 0,
                intervalUsage: item["current_interval_usage_count"] as? Int ?? 0,
                startTime: item["start_time"] as? Int64 ?? 0,
                endTime: item["end_time"] as? Int64 ?? 0,
                remainsTime: (item["remains_time"] as? Int64 ?? 0) / 1000,
                weeklyRemainingPercent: item["current_weekly_remaining_percent"] as? Int ?? 0,
                weeklyStatus: item["current_weekly_status"] as? Int ?? 0,
                weeklyTotal: item["current_weekly_total_count"] as? Int ?? 0,
                weeklyUsage: item["current_weekly_usage_count"] as? Int ?? 0,
                weeklyStartTime: item["weekly_start_time"] as? Int64 ?? 0,
                weeklyEndTime: item["weekly_end_time"] as? Int64 ?? 0,
                weeklyRemainsTime: (item["weekly_remains_time"] as? Int64 ?? 0) / 1000
            )
        }

        guard !plans.isEmpty else {
            if Self.verbose { Self.logger.error("\(Self.t)model_remains 解析为空，返回配额不可用 rawCount=\(modelRemains.count)") }
            return .unavailable
        }

        if Self.verbose { 
            let modelNames = plans.map { $0.modelName }.joined(separator: ", ")
            Self.logger.info("\(Self.t)查询成功 模型数量=\(plans.count) 模型列表=\(modelNames)") 
        }
        return .success(plans)
    }
}
