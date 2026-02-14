import Foundation
import OSLog
import MagicKit

/// LLM API 服务
///
/// 专门负责大语言模型 API 请求，包括消息发送、流式响应等。
@MainActor
class LLMAPIService: SuperLog {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose = true

    static let shared = LLMAPIService()

    private let apiService = APIService.shared

    private init() {
        if Self.verbose {
            os_log("\(self.t)LLM API 服务已初始化")
        }
    }

    // MARK: - LLM 请求

    /// 发送聊天完成请求到 LLM 供应商
    /// - Parameters:
    ///   - url: API 端点 URL
    ///   - apiKey: API 密钥
    ///   - body: 请求体（符合供应商格式）
    /// - Returns: 原始响应数据
    func sendChatRequest(
        url: URL,
        apiKey: String,
        body: [String: Any]
    ) async throws -> Data {
        // 构建请求头
        var headers = [
            "Content-Type": "application/json",
            "x-api-key": apiKey
        ]

        // 发送请求（使用原始数据，不需要解码）
        let (data, _) = try await sendRawRequest(
            url: url,
            method: .post,
            headers: headers,
            body: body
        )

        return data
    }

    /// 发送流式聊天请求（SSE - Server-Sent Events）
    /// - Parameters:
    ///   - url: API 端点 URL
    ///   - apiKey: API 密钥
    ///   - body: 请求体
    ///   - onChunk: 接收每个数据块的回调
    func sendStreamingRequest(
        url: URL,
        apiKey: String,
        body: [String: Any],
        onChunk: @escaping (String) -> Void
    ) async throws {
        // TODO: 实现流式请求
        // 目前先使用非流式
        throw APIError.requestFailed(underlying: NSError(
            domain: "LLMAPIService",
            code: 501,
            userInfo: [NSLocalizedDescriptionKey: "流式请求尚未实现"]
        ))
    }

    // MARK: - 底层请求方法

    /// 发送原始请求（不解析 JSON）
    private func sendRawRequest(
        url: URL,
        method: HTTPMethod,
        headers: [String: String],
        body: [String: Any]?
    ) async throws -> (Data, URLResponse) {
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
                        os_log("\(self.t)LLM 请求体: \(jsonString.prefix(500))...")
                    }
                }
            } catch {
                os_log(.error, "\(self.t)JSON 序列化失败: \(error.localizedDescription)")
                throw APIError.jsonSerializationFailed(underlying: error)
            }
        }

        // 记录请求信息
        if Self.verbose {
            os_log("\(self.t)发送 LLM \(method.rawValue) 请求到: \(url.absoluteString)")
        }

        do {
            // 发送请求
            let (data, response) = try await apiService.session.data(for: request)

            // 验证响应
            try validateResponse(response, data: data)

            if Self.verbose {
                os_log("\(self.t)LLM 请求成功，收到 \(data.count) 字节数据")
            }

            return (data, response)

        } catch let error as APIError {
            // 重新抛出 API 错误
            throw error
        } catch {
            // 其他错误转换为 API 请求失败
            os_log(.error, "\(self.t)LLM 请求失败: \(error.localizedDescription)")
            throw APIError.requestFailed(underlying: error)
        }
    }

    // MARK: - 响应验证

    /// 验证 LLM API 响应
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // 检查状态码
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            os_log(.error, "\(self.t)LLM API 错误 \(httpResponse.statusCode): \(errorStr.prefix(200))")

            // 详细的错误信息
            let errorMessage = """
            HTTP Error (\(httpResponse.statusCode))
            URL: \(response.url?.absoluteString ?? "Unknown")
            Response: \(errorStr.prefix(500))
            """

            throw APIError.httpError(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
        }
    }
}
