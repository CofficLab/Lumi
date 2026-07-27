import Foundation
import HttpKit
import LLMKit
import LumiKernel
import SuperLogKit
import os

/// MiniMax Token Plan 配额服务
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
    static func fetchTokenPlan() async -> TokenPlanStatus {
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

        let client = HTTPClient(timeoutIntervalForRequest: timeout, timeoutIntervalForResource: timeout)

        do {
            let (data, response) = try await client.sendRequestWithResponse(request: request)

            if Self.verbose {
                let bodyPreview = String(data: data, encoding: .utf8) ?? "<非 UTF-8 数据>"
                Self.logger.info("\(Self.t)收到响应 statusCode=\(response.statusCode) body=\(bodyPreview)")
            }

            // 解析 JSON
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                if Self.verbose { Self.logger.error("\(Self.t)响应体不是合法 JSON，返回配额不可用 bytes=\(data.count)") }
                return .unavailable
            }

            // 检查业务状态码
            if let statusCode = json["status_code"] as? Int, statusCode != 0 {
                let baseResp = json["base_resp"] as? [String: Any]
                let errorMessage = baseResp?["message"] as? String ?? "未知错误"
                if statusCode == 1001 || statusCode == 1002 {
                    if Self.verbose { Self.logger.warning("\(Self.t)业务状态码=\(statusCode)，返回认证失败 message=\(errorMessage)") }
                    return .authError
                }
                if Self.verbose { Self.logger.error("\(Self.t)业务状态码非 0，返回配额不可用 status_code=\(statusCode) message=\(errorMessage)") }
                return .unavailable
            }

            // 提取配额数据：新版接口返回顶层 model_remains 数组
            guard let modelRemains = json["model_remains"] as? [[String: Any]], !modelRemains.isEmpty else {
                if Self.verbose { Self.logger.error("\(Self.t)响应缺少 model_remains 字段，返回配额不可用 keys=\(json.keys.joined(separator: ","))") }
                return .unavailable
            }

            // 解析模型配额列表
            let plans = modelRemains.compactMap { item -> TokenPlanData? in
                guard let modelName = item["model_name"] as? String else {
                    return nil
                }

                return TokenPlanData(
                    modelName: modelName,
                    remainingPercent: item["current_interval_remaining_percent"] as? Int ?? 0,
                    weeklyRemainingPercent: item["current_weekly_remaining_percent"] as? Int ?? 0,
                    intervalTotal: item["current_interval_total_count"] as? Int ?? 0,
                    intervalUsage: item["current_interval_usage_count"] as? Int ?? 0
                )
            }

            guard !plans.isEmpty else {
                if Self.verbose { Self.logger.error("\(Self.t)model_remains 解析为空，返回配额不可用 rawCount=\(modelRemains.count)") }
                return .unavailable
            }

            // 选择剩余百分比最低的模型作为状态栏展示（最紧张的一个优先提醒）
            let bestPlan = plans.min { $0.remainingPercent < $1.remainingPercent }!
            if Self.verbose { Self.logger.info("\(Self.t)查询成功 模型=\(bestPlan.modelName) 剩余=\(bestPlan.remainingPercent)% 本周=\(bestPlan.weeklyRemainingPercent)%") }
            return .success(bestPlan)

        } catch let error as HTTPClientError {
            if case let .httpError(statusCode, message) = error {
                if statusCode == 401 || statusCode == 403 {
                    if Self.verbose { Self.logger.warning("\(Self.t)HTTP \(statusCode)，返回认证失败 message=\(message)") }
                    return .authError
                }
                if Self.verbose { Self.logger.error("\(Self.t)HTTP 请求失败，返回配额不可用 statusCode=\(statusCode) message=\(message)") }
            } else if Self.verbose {
                Self.logger.error("\(Self.t)HTTP 客户端错误，返回配额不可用 error=\(String(describing: error))")
            }
            return .unavailable
        } catch {
            if Self.verbose { Self.logger.error("\(Self.t)未知错误，返回配额不可用 error=\(String(describing: error))") }
            return .unavailable
        }
    }
}
