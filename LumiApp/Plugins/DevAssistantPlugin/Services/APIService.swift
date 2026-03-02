import Foundation
import OSLog
import MagicKit

/// API 服务
///
/// 负责所有 HTTP API 请求的统一管理，包括请求构建、发送、错误处理和重试机制。
@MainActor
class APIService: SuperLog {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose = true

    static let shared = APIService()

    let session: URLSession
    private let decoder: JSONDecoder
    
    // MARK: - 重试配置
    
    /// 最大重试次数
    static let maxRetries: Int = 3
    
    /// 初始重试等待时间（秒）
    let baseRetryDelay: Double = 1.0
    
    /// 重试退避倍数（指数增长）
    let retryBackoffMultiplier: Double = 2.0

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300  // 5 分钟超时（LLM 需要更多时间）
        configuration.timeoutIntervalForResource = 600  // 10 分钟资源超时
        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()

        if Self.verbose {
            os_log("\(self.t)API 服务已初始化（最大重试次数：\(Self.maxRetries)）")
        }
    }

    // MARK: - 错误判断

    /// 判断错误是否可重试
    func isRetryableError(_ error: Error) -> Bool {
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
    func calculateRetryDelay(for attempt: Int) -> Double {
        let delay = baseRetryDelay * pow(retryBackoffMultiplier, Double(attempt - 1))
        let jitter = Double.random(in: 0...0.5)
        return delay + jitter
    }

    // MARK: - 请求发送

    /// 发送 JSON 编码的 POST 请求（带重试机制）
    func sendRequest<T: Decodable>(
        url: URL,
        method: HTTPMethod = .post,
        headers: [String: String] = [:],
        body: [String: Any]? = nil,
        responseType: T.Type
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...Self.maxRetries {
            do {
                if Self.verbose && attempt > 1 {
                    os_log("\(self.t)🔄 重试请求 (尝试 \(attempt)/\(Self.maxRetries))")
                }
                
                let result = try await sendRequestWithoutRetry(
                    url: url,
                    method: method,
                    headers: headers,
                    body: body,
                    responseType: responseType
                )
                
                if Self.verbose && attempt > 1 {
                    os_log("\(self.t)✅ 重试成功")
                }
                
                return result
                
            } catch {
                lastError = error
                
                if attempt < Self.maxRetries && isRetryableError(error) {
                    let delay = calculateRetryDelay(for: attempt)
                    os_log("\(self.t)⚠️ 请求失败 (\(error.localizedDescription))，\(Int(delay)) 秒后重试...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    if Self.verbose {
                        os_log("\(self.t)❌ 请求最终失败：\(error.localizedDescription)")
                    }
                    throw error
                }
            }
        }
        
        throw lastError ?? APIError.requestFailed(underlying: NSError(
            domain: "APIService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "未知错误"]
        ))
    }
    
    /// 发送不带重试的原始请求
    private func sendRequestWithoutRetry<T: Decodable>(
        url: URL,
        method: HTTPMethod = .post,
        headers: [String: String] = [:],
        body: [String: Any]? = nil,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 300

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body = body {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: body)
                request.httpBody = jsonData

                if Self.verbose {
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        os_log("\(self.t)请求体：\(jsonString.prefix(500))...")
                    }
                }
            } catch {
                os_log(.error, "\(self.t)JSON 序列化失败：\(error.localizedDescription)")
                throw APIError.jsonSerializationFailed(underlying: error)
            }
        }

        if Self.verbose {
            os_log("\(self.t)发送 \(method.rawValue) 请求到：\(url.absoluteString)")
        }

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)

            do {
                let result = try decoder.decode(T.self, from: data)
                if Self.verbose {
                    os_log("\(self.t)请求成功，响应已解码")
                }
                return result
            } catch {
                os_log(.error, "\(self.t)响应解码失败：\(error.localizedDescription)")
                throw APIError.decodingFailed(underlying: error)
            }

        } catch let error as APIError {
            throw error
        } catch {
            os_log(.error, "\(self.t)请求失败：\(error.localizedDescription)")
            throw APIError.requestFailed(underlying: error)
        }
    }

    // MARK: - 响应验证

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            os_log(.error, "\(self.t)HTTP 错误 \(httpResponse.statusCode): \(errorStr.prefix(200))")
            throw APIError.httpError(
                statusCode: httpResponse.statusCode,
                message: errorStr
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