import Foundation
import MagicKit
import Security

/// LLM API 服务
///
/// 专门负责大语言模型 API 请求，包括消息发送、流式响应等。
/// 此类是纯粹的网络层，不包含重试逻辑——重试策略由调用方统一管理。
class LLMAPIService: SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = false
    /// URLSession 配置
    private nonisolated let session: URLSession
    private nonisolated let tlsDelegate: TLSValidationDelegate

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300 // 5 分钟超时（LLM 需要更多时间）
        configuration.timeoutIntervalForResource = 600 // 10 分钟资源超时
        self.tlsDelegate = TLSValidationDelegate()
        self.session = URLSession(
            configuration: configuration,
            delegate: tlsDelegate,
            delegateQueue: nil
        )

        if Self.verbose {
            AppLogger.core.info("\(self.t)✅ LLM API 服务已初始化")
        }
    }

    // MARK: - LLM 请求

    /// 发送聊天完成请求（单次，不含重试）。
    ///
    /// 重试策略由 `LLMRequester` 统一管理。
    ///
    /// - Parameters:
    ///   - request: 已构建好的 URLRequest（包含 URL、Headers、Method 等）
    ///   - body: 请求体字典
    /// - Returns: 响应数据
    /// - Throws: 网络错误或 API 错误
    func sendChatRequest(
        request: URLRequest,
        body: [String: Any]
    ) async throws -> Data {
        var mutableRequest = request

        // 序列化请求体
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            mutableRequest.httpBody = jsonData
        } catch {
            AppLogger.core.error("\(self.t)JSON 序列化失败：\(error.localizedDescription)")
            throw APIError.jsonSerializationFailed(underlying: error)
        }

        if Self.verbose {
            let allHeaders = mutableRequest.allHTTPHeaderFields ?? [:]
            AppLogger.core.info("\(self.t)LLM 请求头:")
            for (key, value) in allHeaders {
                let maskedValue = maskSensitiveValue(key: key, value: value)
                AppLogger.core.info("\(self.t)  \(key): \(maskedValue)")
            }
        }

        if Self.verbose {
            let url = mutableRequest.url?.absoluteString ?? "unknown"
            let method = mutableRequest.httpMethod ?? "unknown"
            AppLogger.core.info("\(self.t)发送 LLM \(method) 请求到：\(url)")
        }

        do {
            let (data, response) = try await session.data(for: mutableRequest)
            try validateResponse(response, data: data)

            if Self.verbose {
                AppLogger.core.info("\(self.t)LLM 请求成功，收到 \(data.count) 字节数据")
            }

            return data

        } catch let error as APIError {
            throw error
        } catch {
            AppLogger.core.error("\(self.t)LLM 请求失败：\(error.localizedDescription)")
            throw APIError.requestFailed(underlying: error)
        }
    }

    /// 发送流式聊天请求
    ///
    /// 使用 SSE (Server-Sent Events) 协议接收流式响应
    ///
    /// - Parameters:
    ///   - request: 已构建好的 URLRequest（由 provider.buildRequest 构建）
    ///   - body: 请求体字典
    ///   - onRequestStart: 请求开始时的回调（包含请求元数据）
    ///   - onChunk: 收到数据块时的回调（返回 false 则停止接收）
    /// - Throws: 网络错误或 API 错误
    func sendStreamingRequest(
        request: URLRequest,
        body: [String: Any],
        onRequestStart: @Sendable @escaping (RequestMetadata) async -> Void = { _ in },
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        var mutableRequest = request

        // 添加流式请求专用的 Accept 头
        mutableRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        // 序列化请求体
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: body)
            mutableRequest.httpBody = jsonData
        } catch {
            AppLogger.core.error("\(self.t)JSON 序列化失败：\(error.localizedDescription)")
            throw APIError.jsonSerializationFailed(underlying: error)
        }

        // 设置超时
        mutableRequest.timeoutInterval = 300

        // 📊 获取请求大小并通知调用方
        let requestSizeBytes = jsonData.count
        // 按请求记录完整 body
        let bodyPreview: String? = String(data: jsonData, encoding: .utf8)
        let allHeaders = mutableRequest.allHTTPHeaderFields ?? [:]
        let maskedHeaders = sanitizeHeaders(allHeaders)
        let metadata = RequestMetadata(
            requestId: UUID(),
            method: mutableRequest.httpMethod ?? "POST",
            url: mutableRequest.url?.absoluteString ?? "unknown",
            requestHeaders: maskedHeaders,
            requestBodySizeBytes: requestSizeBytes,
            requestBodyPreview: bodyPreview,
            sentAt: Date(),
            responseStatusCode: nil,
            responseHeaders: nil,
            duration: nil,
            error: nil
        )

        // 在发送前通知调用方
        await onRequestStart(metadata)

        if Self.verbose {
            // 构建完整请求信息
            var logMessage = "\(self.t)🚀 发送流式请求到：\(mutableRequest.url?.absoluteString ?? "unknown")\n"

            // 添加请求体
            if let bodyString = String(data: jsonData, encoding: .utf8) {
                let formattedSize = metadata.formattedBodySize
                if bodyString.count <= 400 {
                    logMessage += "📦 请求体 (\(formattedSize))：\n\(bodyString)\n"
                } else {
                    let prefix = bodyString.prefix(200)
                    let suffix = bodyString.suffix(200)
                    logMessage += "📦 请求体 (\(formattedSize))：\n\(prefix)\n...\n\(suffix)\n"
                }
            }

            // 添加请求头
            logMessage += "📋 请求头：\n"
            for (key, value) in allHeaders {
                // ✅ 敏感信息显示首尾，中间用星号
                let logValue = maskSensitiveValue(key: key, value: value)
                logMessage += "  - \(key): \(logValue)\n"
            }

            AppLogger.core.info("\(logMessage)")
        }

        // 发送请求并处理流式响应
        let (bytes, response) = try await session.bytes(for: mutableRequest)

        // 验证响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorStr)
        }

        if Self.verbose {
            AppLogger.core.info("\(self.t)✅ 流式连接已建立，开始接收数据...")
        }

        // 读取 SSE 数据流（线性字节状态机，避免逐字节全量 range 扫描）
        var eventBuffer = Data()
        var lastBytes: [UInt8] = []
        var chunkCount = 0

        for try await byte in bytes {
            try Task.checkCancellation()
            eventBuffer.append(byte)
            lastBytes.append(byte)
            if lastBytes.count > 4 {
                lastBytes.removeFirst(lastBytes.count - 4)
            }

            // 事件分隔符：\n\n 或 \r\n\r\n
            let hitLF = lastBytes.suffix(2).elementsEqual([0x0A, 0x0A])
            let hitCRLF = lastBytes.count >= 4 && lastBytes.suffix(4).elementsEqual([0x0D, 0x0A, 0x0D, 0x0A])

            if hitLF || hitCRLF {
                let delimiterLength = hitCRLF ? 4 : 2
                guard eventBuffer.count >= delimiterLength else {
                    eventBuffer.removeAll(keepingCapacity: true)
                    lastBytes.removeAll(keepingCapacity: true)
                    continue
                }

                let eventData = eventBuffer.dropLast(delimiterLength)
                eventBuffer.removeAll(keepingCapacity: true)
                lastBytes.removeAll(keepingCapacity: true)

                guard !eventData.isEmpty else { continue }
                chunkCount += 1
                let shouldContinue = await onChunk(Data(eventData))
                if !shouldContinue {
                    if Self.verbose {
                        AppLogger.core.info("\(self.t)🛑 收到停止信号，主动结束流式读取")
                    }
                    return
                }
            }
        }

        // 处理剩余未以空行结束的事件
        if !eventBuffer.isEmpty {
            if Self.verbose {
                let preview = String(data: eventBuffer, encoding: .utf8)?.prefix(200) ?? "无法解码"
                AppLogger.core.info("\(self.t)📦 处理剩余数据 (\(eventBuffer.count) bytes): \(preview)...")
            }
            let shouldContinue = await onChunk(eventBuffer)
            if !shouldContinue {
                if Self.verbose {
                    AppLogger.core.info("\(self.t)🛑 收到停止信号，主动结束流式读取")
                }
                return
            }
        }

        if Self.verbose {
            AppLogger.core.info("\(self.t)✅ 流式响应接收完成")
        }
    }

    /// 屏蔽敏感信息（用于元数据记录）
    private func sanitizeHeaders(_ headers: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in headers {
            let lower = key.lowercased()
            if lower.contains("authorization") || lower.contains("api-key") || lower.hasSuffix("key") || lower.contains("token") {
                result[key] = "***"
            } else {
                result[key] = value
            }
        }
        return result
    }

    /// ✅ 对敏感值进行脱敏处理（用于日志输出）
    /// 显示首尾各 3-4 个字符，中间用星号代替
    private func maskSensitiveValue(key: String, value: String) -> String {
        let lowerKey = key.lowercased()

        // 判断是否为敏感字段
        let isSensitive = lowerKey.contains("authorization") ||
            lowerKey.contains("api-key") ||
            lowerKey.hasSuffix("key") ||
            lowerKey.contains("token")

        if !isSensitive {
            return value
        }

        // 敏感信息脱敏
        if value.count <= 8 {
            // 短值：显示前 2 后 2，中间星号
            let prefix = value.prefix(2)
            let suffix = value.suffix(2)
            return "\(prefix)***\(suffix)"
        } else {
            // 长值：显示前 4 后 4，中间星号
            let prefix = value.prefix(4)
            let suffix = value.suffix(4)
            let starCount = max(3, value.count - 8)
            let stars = String(repeating: "*", count: starCount)
            return "\(prefix)\(stars)\(suffix)"
        }
    }

    // MARK: - 响应验证

    /// 验证 LLM API 响应
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            AppLogger.core.error("\(self.t)LLM API 错误 \(httpResponse.statusCode): \(errorStr.prefix(1000))")

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
        case let .jsonSerializationFailed(error):
            return "JSON 序列化失败：\(error.localizedDescription)"
        case let .requestFailed(error):
            return "请求失败：\(error.localizedDescription)"
        case let .decodingFailed(error):
            return "响应解码失败：\(error.localizedDescription)"
        case .invalidResponse:
            return "无效的响应"
        case let .httpError(code, message):
            return "HTTP 错误 (\(code)): \(message)"
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

/// URLSession 委托：强制使用系统默认的 TLS 证书校验（系统信任库）。
/// 拒绝自签名、过期或域名不匹配的证书，降低中间人攻击风险。
private final class TLSValidationDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)
        if isValid {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
