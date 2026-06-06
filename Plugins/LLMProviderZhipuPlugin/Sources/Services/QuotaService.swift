import Foundation
import HttpKit
import os
import SuperLogKit

/// 智谱配额查询辅助工具
enum QuotaService: SuperLog {
    nonisolated static let emoji = "📊"
    nonisolated static let verbose: Bool = false

    /// 请求超时时间（秒）
    private static let timeout: TimeInterval = 5.0

    /// 获取配额信息
    /// - Returns: 配额结果
    static func fetchQuota() async -> (status: QuotaStatus, data: QuotaData?) {
        if Self.verbose {
            if ZhipuPlugin.verbose {
                ZhipuPlugin.logger.info("\(Self.t)开始获取配额信息")
            }
        }

        // 获取 API Key
        let apiKey = ZhipuProvider.getApiKey()
        guard !apiKey.isEmpty else {
            if Self.verbose {
                if ZhipuPlugin.verbose {
                    ZhipuPlugin.logger.warning("\(Self.t)API Key 为空，跳过配额查询")
                }
            }
            return (.authError, nil)
        }

        let quotaURL = "https://open.bigmodel.cn/api/monitor/usage/quota/limit"

        guard let url = URL(string: quotaURL) else {
            if ZhipuPlugin.verbose {
                ZhipuPlugin.logger.error("\(Self.t)配额 URL 构建失败: \(quotaURL)")
            }
            return (.unavailable, nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout

        let client = HTTPClient(timeoutIntervalForRequest: timeout, timeoutIntervalForResource: timeout)

        do {
            let data = try await client.sendRequest(request: request)

            // 解析 JSON
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let payload = json else {
                if ZhipuPlugin.verbose {
                    ZhipuPlugin.logger.error("\(Self.t)JSON 解析失败")
                }
                return (.unavailable, nil)
            }

            if Self.verbose {
                if ZhipuPlugin.verbose {
                    ZhipuPlugin.logger.debug("\(Self.t)API 原始响应：\(payload)")
                }
            }

            // 检查 success 字段
            if payload["success"] as? Bool != true {
                let code = payload["code"] as? Int
                if code == 1001 || code == 401 {
                    if Self.verbose {
                        if ZhipuPlugin.verbose {
                            ZhipuPlugin.logger.warning("\(Self.t)业务层认证失败，code: \(code ?? -1)")
                        }
                    }
                    return (.authError, nil)
                }
                if Self.verbose {
                    if ZhipuPlugin.verbose {
                        ZhipuPlugin.logger.warning("\(Self.t)业务层返回失败，code: \(code ?? -1)")
                    }
                }
                return (.unavailable, nil)
            }

            // 提取配额数据
            guard let dataDict = payload["data"] as? [String: Any],
                  let limits = dataDict["limits"] as? [[String: Any]] else {
                if ZhipuPlugin.verbose {
                    ZhipuPlugin.logger.error("\(Self.t)配额数据结构异常，缺少 data/limits")
                }
                return (.unavailable, nil)
            }

            // 查找 5 小时滚动窗口限制（TOKENS_LIMIT, number=5）
            let rollingLimit = limits.first { limit in
                (limit["type"] as? String) == "TOKENS_LIMIT" && (limit["number"] as? Int) == 5
            }

            // 查找 MCP 每月额度限制（TIME_LIMIT, unit=5）
            let mcpLimit = limits.first { limit in
                (limit["type"] as? String) == "TIME_LIMIT" && (limit["unit"] as? Int) == 5
            }

            if let rollingLimit = rollingLimit,
               let percentage = rollingLimit["percentage"] as? Int,
               let nextResetTime = rollingLimit["nextResetTime"] as? TimeInterval {
                let usedPercent = min(100, max(0, percentage))
                let leftPercent = 100 - usedPercent
                let level = (dataDict["level"] as? String) ?? ""

                let mcpLeftPercent = mcpLimit?["remaining"] as? Int ?? 0
                let mcpNextResetTime = mcpLimit?["nextResetTime"] as? TimeInterval ?? nextResetTime

                let quotaData = QuotaData(
                    level: level,
                    usedPercent: usedPercent,
                    leftPercent: leftPercent,
                    nextResetTime: nextResetTime,
                    mcpLeftPercent: mcpLeftPercent,
                    mcpNextResetTime: mcpNextResetTime
                )
                if Self.verbose {
                    if ZhipuPlugin.verbose {
                        ZhipuPlugin.logger.info("\(Self.t)配额查询成功(rolling): \(quotaData.statusText)")
                    }
                }
                return (.success(quotaData), nil)
            }

            // 备用方案：如果 TOKENS_LIMIT 不存在，使用 TIME_LIMIT 计算
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

                let mcpLeftPercent = timeLimit["remaining"] as? Int ?? 0
                let mcpNextResetTime = timeLimit["nextResetTime"] as? TimeInterval ?? nextResetTime

                let quotaData = QuotaData(
                    level: level,
                    usedPercent: usedPercent,
                    leftPercent: leftPercent,
                    nextResetTime: nextResetTime,
                    mcpLeftPercent: mcpLeftPercent,
                    mcpNextResetTime: mcpNextResetTime
                )
                if Self.verbose {
                    if ZhipuPlugin.verbose {
                        ZhipuPlugin.logger.info("\(Self.t)配额查询成功(timeLimit fallback): \(quotaData.statusText)")
                    }
                }
                return (.success(quotaData), nil)
            }

            if Self.verbose {
                if ZhipuPlugin.verbose {
                    ZhipuPlugin.logger.warning("\(Self.t)未找到匹配的配额限制类型")
                }
            }
            return (.unavailable, nil)

        } catch let error as HTTPClientError {
            if case let .httpError(statusCode, _) = error {
                if statusCode == 401 || statusCode == 1001 {
                    if Self.verbose {
                        if ZhipuPlugin.verbose {
                            ZhipuPlugin.logger.warning("\(Self.t)认证失败，HTTP \(statusCode)")
                        }
                    }
                    return (.authError, nil)
                }
            }
            if ZhipuPlugin.verbose {
                ZhipuPlugin.logger.error("\(Self.t)网络请求失败: \(error.localizedDescription)")
            }
            return (.unavailable, nil)
        } catch {
            if ZhipuPlugin.verbose {
                ZhipuPlugin.logger.error("\(Self.t)网络请求失败: \(error.localizedDescription)")
            }
            return (.unavailable, nil)
        }
    }
}
