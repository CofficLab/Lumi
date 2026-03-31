import Foundation
import os
import MagicKit

/// 智谱配额数据（本地副本，避免跨模块依赖）
struct ZhipuQuotaData {
    let level: String
    let usedPercent: Int
    let leftPercent: Int
    let nextResetTime: TimeInterval

    /// 等级显示文本
    var levelDisplay: String {
        "GLM \(level.isEmpty ? "Lite" : level)"
    }

    /// 重置时间文本（完整日期时间格式）
    var resetTime: String {
        let date = Date(timeIntervalSince1970: nextResetTime)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    /// 重置时间文本（相对时间格式，如"2 小时后"）
    var resetTimeRelative: String {
        let date = Date(timeIntervalSince1970: nextResetTime)
        let now = Date()
        let interval = date.timeIntervalSince(now)

        if interval < 0 {
            return "即将重置"
        } else if interval < 3600 {
            return "约 \(Int(interval / 60)) 分钟后"
        } else if interval < 86400 {
            return "约 \(Int(interval / 3600)) 小时后"
        } else {
            return "\(Int(interval / 86400)) 天后"
        }
    }

    /// 状态栏显示文本
    var statusText: String {
        "\(levelDisplay) | 剩余 \(leftPercent)% | 重置 \(resetTime)"
    }
}

/// 智谱配额状态（本地副本，避免跨模块依赖）
enum ZhipuQuotaStatus {
    case loading
    case success(ZhipuQuotaData)
    case authError
    case unavailable
}

/// 智谱配额查询辅助工具
enum ZhipuQuotaService {
    /// 日志
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "zhipu-quota-service")
    /// 默认配额 API 端点
    private static let defaultQuotaURL = "https://bigmodel.cn/api/monitor/usage/quota/limit"

    /// 请求超时时间（秒）
    private static let timeout: TimeInterval = 5.0

    /// 获取配额信息
    /// - Returns: 配额结果
    static func fetchQuota() async -> (status: ZhipuQuotaStatus, data: ZhipuQuotaData?) {
        // 获取 API Key
        let apiKey = APIKeyStore.shared.string(forKey: "DevAssistant_ApiKey_Zhipu") ?? ""
        guard !apiKey.isEmpty else {
            return (.authError, nil)
        }

        // 获取 Base URL（推断配额 URL）
        let baseURL = "https://open.bigmodel.cn"
        let quotaURL = "\(baseURL)/api/monitor/usage/quota/limit"

        guard let url = URL(string: quotaURL) else {
            return (.unavailable, nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return (.unavailable, nil)
            }

            // 认证失败
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 1001 {
                return (.authError, nil)
            }

            // 其他错误
            guard httpResponse.statusCode == 200 else {
                return (.unavailable, nil)
            }

            // 解析 JSON
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let payload = json else {
                ZhipuQuotaService.logger.error("解析 JSON 失败")
                return (.unavailable, nil)
            }

            // 记录原始响应
            ZhipuQuotaService.logger.debug("API 原始响应：\(payload)")

            // 检查 success 字段
            if payload["success"] as? Bool != true {
                let code = payload["code"] as? Int
                if code == 1001 || code == 401 {
                    return (.authError, nil)
                }
                return (.unavailable, nil)
            }

            // 提取配额数据
            guard let dataDict = payload["data"] as? [String: Any],
                  let limits = dataDict["limits"] as? [[String: Any]] else {
                return (.unavailable, nil)
            }

            // 查找 5 小时滚动窗口限制
            let rollingLimit = limits.first { limit in
                (limit["type"] as? String) == "TOKENS_LIMIT" && (limit["number"] as? Int) == 5
            }

            if let rollingLimit = rollingLimit,
               let percentage = rollingLimit["percentage"] as? Int,
               let nextResetTime = rollingLimit["nextResetTime"] as? TimeInterval {
                let usedPercent = min(100, max(0, percentage))
                let leftPercent = 100 - usedPercent
                let level = (dataDict["level"] as? String) ?? ""

                return (.success(ZhipuQuotaData(
                    level: level,
                    usedPercent: usedPercent,
                    leftPercent: leftPercent,
                    nextResetTime: nextResetTime
                )), nil)
            }

            // 查找时间限制（备用方案）
            let timeLimit = limits.first { limit in
                (limit["type"] as? String) == "TIME_LIMIT" && (limit["unit"] as? Int) == 5
            }

            if let timeLimit = timeLimit,
               let remaining = timeLimit["remaining"] as? Int,
               let usage = timeLimit["usage"] as? Int,
               let nextResetTime = timeLimit["nextResetTime"] as? TimeInterval {
                let total = remaining + usage
                let usedPercent = total > 0 ? Int((Double(usage) / Double(total)) * 100) : 0
                let leftPercent = 100 - usedPercent
                let level = (dataDict["level"] as? String) ?? ""

                return (.success(ZhipuQuotaData(
                    level: level,
                    usedPercent: usedPercent,
                    leftPercent: leftPercent,
                    nextResetTime: nextResetTime
                )), nil)
            }

            return (.unavailable, nil)

        } catch {
            return (.unavailable, nil)
        }
    }
}
