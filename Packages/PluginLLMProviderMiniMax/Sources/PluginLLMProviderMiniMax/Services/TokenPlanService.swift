import Foundation
import KitLLM
import LumiLoggingKit
import os

/// MiniMax Token Plan 配额服务。
///
/// 请求 `GET https://www.minimaxi.com/v1/token_plan/remains`，解析顶层
/// `model_remains` 数组。传输走宿主注入的 ``VendorAPIService``（内部优先走
/// `LLMNetworkProviding`，保留 HTTP 交换记录），API Key 走 `VendorAPIKeyTools`
/// 复用既有 Keychain 条目 `DevAssistant_ApiKey_MiniMax`。
enum TokenPlanService: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.llm-provider.minimax",
        category: "TokenPlan"
    )
    nonisolated static let emoji = "🎯"
    nonisolated static let verbose = false

    /// 配额查询端点。
    nonisolated static let endpoint = "https://www.minimaxi.com/v1/token_plan/remains"

    /// 请求超时（秒）。配额查询是锦上添花的信息，不值得让用户等。
    private static let timeout: TimeInterval = 5.0

    /// 业务层认证失败的状态码，与 HTTP 401/403 一并归为「需要检查 API Key」。
    private static let businessAuthStatusCodes: Set<Int> = [1001, 1002]

    /// 查询 Token Plan 配额。
    ///
    /// - Parameters:
    ///   - apiService: 传输服务。
    ///   - apiKeyStorageKey: API Key 的 Keychain storage key。
    /// - Returns: 解析后的配额；任何失败都归类为 `authError` / `unavailable`，
    ///   不向上抛错——配额不可用不应影响聊天主链路。
    static func fetchTokenPlan(
        apiService: VendorAPIService,
        apiKeyStorageKey: String
    ) async -> TokenPlanStatus {
        let apiKey = VendorAPIKeyTools.get(storageKey: apiKeyStorageKey)
        guard !apiKey.isEmpty else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)API Key 为空，返回认证失败")
            }
            return .authError
        }

        guard let url = URL(string: Self.endpoint) else {
            Self.logger.error("\(Self.t)URL 非法，返回配额不可用 url=\(Self.endpoint)")
            return .unavailable
        }

        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        if Self.verbose {
            Self.logger.info("\(Self.t)开始查询 Token Plan 配额 url=\(Self.endpoint)")
        }

        let data: Data
        do {
            data = try await apiService.send(request: request)
        } catch let error as VendorAPIError {
            if Self.isAuthFailure(error) {
                if Self.verbose { Self.logger.warning("\(Self.t)认证失败：\(error.localizedDescription)") }
                return .authError
            }
            if Self.verbose {
                Self.logger.error("\(Self.t)请求失败，返回配额不可用 error=\(String(describing: error))")
            }
            return .unavailable
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)未知错误，返回配额不可用 error=\(String(describing: error))")
            }
            return .unavailable
        }

        // JSON 解析与模型构造放到后台任务，避免网络返回后占用主线程。
        return await Task.detached(priority: .utility) {
            Self.processResponse(data: data)
        }.value
    }

    // MARK: - Response

    /// 解析响应体。
    ///
    /// 独立成 `nonisolated` 纯函数以便单测直接覆盖。
    nonisolated static func processResponse(data: Data) -> TokenPlanStatus {
        if Self.verbose {
            // 仅保留有限长度的预览，避免异常响应或错误页造成日志膨胀。
            let preview = String(data: data.prefix(4_096), encoding: .utf8) ?? "<非 UTF-8 数据>"
            Self.logger.info("\(Self.t)收到响应 bytes=\(data.count) bodyPreview=\(preview)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Self.logger.error("\(Self.t)响应体不是合法 JSON，返回配额不可用")
            return .unavailable
        }

        // 先看 base_resp 的业务状态码：HTTP 200 也可能是业务失败。
        if let baseResp = json["base_resp"] as? [String: Any] {
            let statusCode = baseResp["status_code"] as? Int ?? 0
            if statusCode != 0 {
                let message = baseResp["status_msg"] as? String ?? "未知错误"
                if Self.businessAuthStatusCodes.contains(statusCode) {
                    Self.logger.warning("\(Self.t)业务状态码=\(statusCode)，返回认证失败 message=\(message)")
                    return .authError
                }
                Self.logger.error("\(Self.t)业务状态码非 0，返回配额不可用 status_code=\(statusCode) message=\(message)")
                return .unavailable
            }
        }

        guard let modelRemains = json["model_remains"] as? [[String: Any]], !modelRemains.isEmpty else {
            Self.logger.error("\(Self.t)响应缺少 model_remains 字段，返回配额不可用 keys=\(json.keys.sorted().joined(separator: ","))")
            return .unavailable
        }

        let plans = modelRemains.compactMap(Self.makePlan(from:))
        guard !plans.isEmpty else {
            Self.logger.error("\(Self.t)model_remains 解析为空，返回配额不可用 rawCount=\(modelRemains.count)")
            return .unavailable
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)查询成功 模型数量=\(plans.count) 模型列表=\(plans.map(\.modelName).joined(separator: ", "))")
        }
        return .success(plans)
    }

    /// 单条 `model_remains` → `TokenPlanData`；缺 `model_name` 时丢弃该条。
    nonisolated static func makePlan(from item: [String: Any]) -> TokenPlanData? {
        guard let modelName = item["model_name"] as? String else { return nil }
        return TokenPlanData(
            modelName: modelName,
            remainingPercent: item["current_interval_remaining_percent"] as? Int ?? 0,
            intervalStatus: item["current_interval_status"] as? Int ?? 0,
            intervalTotal: item["current_interval_total_count"] as? Int ?? 0,
            intervalUsage: item["current_interval_usage_count"] as? Int ?? 0,
            startTime: int64(item["start_time"]) ?? 0,
            endTime: int64(item["end_time"]) ?? 0,
            // 接口返回毫秒，统一收敛为秒。
            remainsTime: (int64(item["remains_time"]) ?? 0) / 1_000,
            weeklyRemainingPercent: item["current_weekly_remaining_percent"] as? Int ?? 0,
            weeklyStatus: item["current_weekly_status"] as? Int ?? 0,
            weeklyTotal: item["current_weekly_total_count"] as? Int ?? 0,
            weeklyUsage: item["current_weekly_usage_count"] as? Int ?? 0,
            weeklyStartTime: int64(item["weekly_start_time"]) ?? 0,
            weeklyEndTime: int64(item["weekly_end_time"]) ?? 0,
            weeklyRemainsTime: (int64(item["weekly_remains_time"]) ?? 0) / 1_000
        )
    }

    // MARK: - Private

    /// JSON 数字可能是 `Int` / `Double` / `NSNumber`，统一按 64 位整数取值。
    private nonisolated static func int64(_ value: Any?) -> Int64? {
        switch value {
        case let number as Int64: return number
        case let number as Int: return Int64(number)
        case let number as Double: return Int64(number)
        case let number as NSNumber: return number.int64Value
        default: return nil
        }
    }

    private nonisolated static func isAuthFailure(_ error: VendorAPIError) -> Bool {
        guard case let .httpStatus(code, _, _) = error else { return false }
        return code == 401 || code == 403
    }
}
