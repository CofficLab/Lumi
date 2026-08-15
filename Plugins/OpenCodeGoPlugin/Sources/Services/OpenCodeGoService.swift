import Foundation
import KernelLumi
import SuperLogKit
import os

/// OpenCode Go 配额服务
@MainActor
enum OpenCodeGoService: SuperLog {
    /// 请求超时时间（秒）
    private static let timeout: TimeInterval = 3.0

    /// 本地 API 基础 URL
    private static let baseURL = "http://127.0.0.1:8765"

    /// 日志分类，遵循 com.coffic.lumi 子系统规范
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "opencodego")

    /// 标识 emoji
    nonisolated static let emoji = "🚀"

    /// 调试开关
    nonisolated(unsafe) static var verbose: Bool = false

    /// 获取 OpenCode Go 配额状态
    static func fetchState(network: (any NetworkProviding)? = nil) async -> OpenCodeGoStatus {
        let stateURL = "\(baseURL)/api/state"

        if Self.verbose { Self.logger.info("\(Self.t)开始查询 OpenCode Go 状态 url=\(stateURL)") }

        guard let url = URL(string: stateURL) else {
            if Self.verbose { Self.logger.error("\(Self.t)URL 非法，返回配额不可用 url=\(stateURL)") }
            return .unavailable("URL 无效")
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = timeout

        do {
            let response = try await network?.request(HTTPRequest(
                url: url,
                method: .get,
                headers: [:],
                timeout: timeout
            ))

            guard let response else {
                return .unavailable("网络服务不可用")
            }

            let data = response.body
            let statusCode = response.statusCode

            return await Task.detached(priority: .utility) {
                Self.processResponse(data: data, statusCode: statusCode)
            }.value

        } catch let error as HTTPNetworkError {
            if Self.verbose {
                Self.logger.error("\(Self.t)HTTP 请求失败 error=\(String(describing: error))")
            }
            return .unavailable("连接失败: \(error.localizedDescription)")
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)未知错误 error=\(String(describing: error))")
            }
            return .unavailable("请求失败")
        }
    }

    /// 在后台处理响应，避免完整 body 日志和 JSONSerialization 运行在主线程。
    nonisolated private static func processResponse(data: Data, statusCode: Int) -> OpenCodeGoStatus {
        if Self.verbose {
            let bodyPreview = String(data: data.prefix(4096), encoding: .utf8) ?? "<非 UTF-8 数据>"
            Self.logger.info("\(Self.t)收到响应 statusCode=\(statusCode) bytes=\(data.count) bodyPreview=\(bodyPreview)")
        }

        guard statusCode == 200 else {
            if Self.verbose { Self.logger.error("\(Self.t)HTTP 状态码非 200 statusCode=\(statusCode)") }
            return .unavailable("服务响应异常")
        }

        do {
            let state = try JSONDecoder().decode(OpenCodeGoState.self, from: data)

            if Self.verbose {
                Self.logger.info("\(Self.t)解析成功 windows=\(state.windows.count) rows=\(state.rows) key=\(state.key)")
            }

            return .success(state)
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)JSON 解析失败 error=\(String(describing: error))")
            }
            return .unavailable("数据解析失败")
        }
    }
}
