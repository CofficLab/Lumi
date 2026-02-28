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

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60  // 60 秒超时
        configuration.timeoutIntervalForResource = 120  // 120 秒资源超时
        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()

        if Self.verbose {
            os_log("\(self.t)API 服务已初始化")
        }
    }

    // MARK: - 请求发送

    /// 发送 JSON 编码的 POST 请求
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - headers: HTTP 请求头
    ///   - body: 请求体（字典）
    /// - Returns: 解码后的响应对象
    func sendRequest<T: Decodable>(
        url: URL,
        method: HTTPMethod = .post,
        headers: [String: String] = [:],
        body: [String: Any]? = nil,
        responseType: T.Type
    ) async throws -> T {
        // 构建 URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 60

        // 设置请求头
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // 设置请求体
        if let body = body {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: body)
                request.httpBody = jsonData

                if Self.verbose {
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        os_log("\(self.t)请求体: \(jsonString.prefix(500))...")
                    }
                }
            } catch {
                os_log(.error, "\(self.t)JSON 序列化失败: \(error.localizedDescription)")
                throw APIError.jsonSerializationFailed(underlying: error)
            }
        }

        // 记录请求信息
        if Self.verbose {
            os_log("\(self.t)发送 \(method.rawValue) 请求到: \(url.absoluteString)")
        }

        do {
            // 发送请求
            let (data, response) = try await session.data(for: request)

            // 验证响应
            try validateResponse(response, data: data)

            // 解析响应
            do {
                let result = try decoder.decode(T.self, from: data)
                if Self.verbose {
                    os_log("\(self.t)请求成功，响应已解码")
                }
                return result
            } catch {
                os_log(.error, "\(self.t)响应解码失败: \(error.localizedDescription)")
                throw APIError.decodingFailed(underlying: error)
            }

        } catch let error as APIError {
            // 重新抛出 API 错误
            throw error
        } catch {
            // 其他错误转换为 API 请求失败
            os_log(.error, "\(self.t)请求失败: \(error.localizedDescription)")
            throw APIError.requestFailed(underlying: error)
        }
    }

    // MARK: - 响应验证

    /// 验证 HTTP 响应状态码
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // 检查状态码是否在成功范围 (200-299)
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

/// API 错误类型
enum APIError: LocalizedError {
    case jsonSerializationFailed(underlying: Error)
    case requestFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case invalidResponse
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .jsonSerializationFailed(let error):
            return "JSON 序列化失败: \(error.localizedDescription)"
        case .requestFailed(let error):
            return "请求失败: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "响应解码失败: \(error.localizedDescription)"
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
