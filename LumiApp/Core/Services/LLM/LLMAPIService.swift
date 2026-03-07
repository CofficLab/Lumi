import Foundation
import OSLog
import MagicKit

/// LLM API 服务
///
/// 专门负责大语言模型 API 请求，包括消息发送、流式响应等。
/// 此类可以在后台线程执行
class LLMAPIService: SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose = true
    
    /// URLSession 配置
    private nonisolated let session: URLSession
    private nonisolated let decoder: JSONDecoder
    
    // MARK: - 重试配置
    
    /// 最大重试次数
    private nonisolated let maxRetries: Int = 3
    
    /// 初始重试等待时间（秒）
    private nonisolated let baseRetryDelay: Double = 1.0
    
    /// 重试退避倍数（指数增长）
    private nonisolated let retryBackoffMultiplier: Double = 2.0
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300  // 5 分钟超时（LLM 需要更多时间）
        configuration.timeoutIntervalForResource = 600  // 10 分钟资源超时
        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()
        
        if Self.verbose {
            os_log("\(self.t)✅ LLM API 服务已初始化（最大重试次数：\(self.maxRetries)）")
        }
    }

    // MARK: - LLM 请求

    /// 发送聊天完成请求到 LLM 供应商（带重试机制）
    func sendChatRequest(
        url: URL,
        apiKey: String,
        body: [String: Any],
        additionalHeaders: [String: String] = [:],
        useBearerAuth: Bool = false
    ) async throws -> Data {
        var headers = [
            "Content-Type": "application/json"
        ]

        if useBearerAuth {
            headers["Authorization"] = "Bearer \(apiKey)"
        } else {
            headers["x-api-key"] = apiKey
        }

        for (key, value) in additionalHeaders {
            headers[key] = value
        }

        let (data, _) = try await sendRawRequestWithRetry(
            url: url,
            method: .post,
            headers: headers,
            body: body
        )

        return data
    }

    /// 发送流式聊天请求
    func sendStreamingRequest(
        url: URL,
        apiKey: String,
        body: [String: Any],
        onChunk: @escaping (String) -> Void
    ) async throws {
        throw APIError.requestFailed(underlying: NSError(
            domain: "LLMAPIService",
            code: 501,
            userInfo: [NSLocalizedDescriptionKey: "流式请求尚未实现"]
        ))
    }

    // MARK: - 带重试的原始请求

    private func sendRawRequestWithRetry(
        url: URL,
        method: HTTPMethod,
        headers: [String: String],
        body: [String: Any]?
    ) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                if Self.verbose && attempt > 1 {
                    os_log("\(self.t)🔄 重试 LLM 请求 (尝试 \(attempt)/\(self.maxRetries))")
                }

                let result = try await sendRawRequest(
                    url: url,
                    method: method,
                    headers: headers,
                    body: body
                )

                if Self.verbose && attempt > 1 {
                    os_log("\(self.t)✅ LLM 重试成功")
                }

                return result

            } catch {
                lastError = error

                if attempt < maxRetries && isRetryableError(error) {
                    let delay = calculateRetryDelay(for: attempt)
                    os_log("\(self.t)⚠️ LLM 请求失败 (\(error.localizedDescription))，\(Int(delay)) 秒后重试...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    if Self.verbose {
                        os_log("\(self.t)❌ LLM 请求最终失败：\(error.localizedDescription)")
                    }
                    throw error
                }
            }
        }

        throw lastError ?? APIError.requestFailed(underlying: NSError(
            domain: "LLMAPIService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "未知错误"]
        ))
    }

    /// 发送原始请求（不解析 JSON）
    private func sendRawRequest(
        url: URL,
        method: HTTPMethod,
        headers: [String: String],
        body: [String: Any]?
    ) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 300

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if Self.verbose {
            os_log("\(self.t)LLM 请求头:")
            for (key, value) in headers {
                let maskedValue = key.lowercased().contains("key") || key.lowercased().contains("auth")
                    ? String(value.prefix(10)) + "..."
                    : value
                os_log("\(self.t)  \(key): \(maskedValue)")
            }
        }

        if let body = body {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: body)
                request.httpBody = jsonData
            } catch {
                os_log(.error, "\(self.t)JSON 序列化失败：\(error.localizedDescription)")
                throw APIError.jsonSerializationFailed(underlying: error)
            }
        }

        if Self.verbose {
            os_log("\(self.t)发送 LLM \(method.rawValue) 请求到：\(url.absoluteString)")
        }

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)

            if Self.verbose {
                os_log("\(self.t)LLM 请求成功，收到 \(data.count) 字节数据")
            }

            return (data, response)

        } catch let error as APIError {
            throw error
        } catch {
            os_log(.error, "\(self.t)LLM 请求失败：\(error.localizedDescription)")
            throw APIError.requestFailed(underlying: error)
        }
    }

    // MARK: - 错误判断

    /// 判断错误是否可重试
    private func isRetryableError(_ error: Error) -> Bool {
        switch error {
        case APIError.requestFailed(let underlying):
            let nsError = underlying as NSError
            if nsError.code == NSURLErrorTimedOut {
                return true
            }
            if nsError.code == NSURLErrorNotConnectedToInternet ||
               nsError.code == NSURLErrorCannotConnectToHost ||
               nsError.code == NSURLErrorNetworkConnectionLost {
                return true
            }
            return false
            
        case APIError.httpError(let statusCode, _):
            if (500 ... 599).contains(statusCode) {
                return true
            }
            if statusCode == 429 {
                return true
            }
            return false
            
        default:
            return false
        }
    }
    
    /// 计算重试延迟时间（指数退避）
    private func calculateRetryDelay(for attempt: Int) -> Double {
        let delay = baseRetryDelay * pow(retryBackoffMultiplier, Double(attempt - 1))
        let jitter = Double.random(in: 0...0.5)
        return delay + jitter
    }

    /// 验证 LLM API 响应
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            os_log(.error, "\(self.t)LLM API 错误 \(httpResponse.statusCode): \(errorStr.prefix(1000))")

            let errorMessage = """
            HTTP Error (\(httpResponse.statusCode))
            URL: \(response.url?.absoluteString ?? "Unknown")
            Response: \(errorStr)
            """

            throw APIError.httpError(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
        }
    }
}

// MARK: - API 错误

enum APIError: LocalizedError {
    case jsonSerializationFailed(underlying: Error)
    case requestFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case invalidResponse
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .jsonSerializationFailed(let error):
            return "JSON 序列化失败：\(error.localizedDescription)"
        case .requestFailed(let error):
            return "请求失败：\(error.localizedDescription)"
        case .decodingFailed(let error):
            return "响应解码失败：\(error.localizedDescription)"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let code, let message):
            return "HTTP 错误 (\(code)): \(message.prefix(200))"
        }
    }
}

// MARK: - HTTP 方法

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
