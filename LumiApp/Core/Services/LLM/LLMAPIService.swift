import Foundation
import MagicKit
import Security

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

/// LLM API 服务
///
/// 专门负责大语言模型 API 请求，包括消息发送、流式响应等。
/// 此类可以在后台线程执行
class LLMAPIService: SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose = false

    /// URLSession 配置
    private nonisolated let session: URLSession
    private nonisolated let decoder: JSONDecoder
    private nonisolated let tlsDelegate: TLSValidationDelegate

    // MARK: - 重试配置

    /// 最大重试次数
    private nonisolated let maxRetries: Int = 3

    /// 初始重试等待时间（秒）
    private nonisolated let baseRetryDelay: Double = 1.0

    /// 重试退避倍数（指数增长）
    private nonisolated let retryBackoffMultiplier: Double = 2.0

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
        self.decoder = JSONDecoder()

        if Self.verbose {
            AppLogger.core.info("\(self.t)✅ LLM API 服务已初始化（最大重试次数：\(self.maxRetries)）")
        }
    }

    // MARK: - LLM 请求

    /// 发送聊天完成请求到 LLM 供应商（带重试机制）
    ///
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - apiKey: API 密钥
    ///   - body: 请求体字典
    ///   - additionalHeaders: 额外的请求头（可包含认证信息）
    /// - Returns: 响应数据
    /// - Throws: 网络错误或 API 错误
    func sendChatRequest(
        url: URL,
        apiKey: String,
        body: [String: Any],
        additionalHeaders: [String: String] = [:]
    ) async throws -> Data {
        // 构建请求头
        // 默认使用 x-api-key 认证，如需 Bearer 认证可通过 additionalHeaders 传递
        var headers = [
            "Content-Type": "application/json",
            "x-api-key": apiKey,
        ]

        // 合并额外的请求头（可覆盖默认值）
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
    ///
    /// 使用 SSE (Server-Sent Events) 协议接收流式响应
    ///
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - apiKey: API 密钥
    ///   - body: 请求体字典
    ///   - additionalHeaders: 额外的请求头
    ///   - onChunk: 收到数据块时的回调
    /// - Throws: 网络错误或 API 错误
    func sendStreamingRequest(
        url: URL,
        apiKey: String,
        body: [String: Any],
        additionalHeaders: [String: String] = [:],
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        // 构建请求头
        var headers = [
            "Content-Type": "application/json",
            "x-api-key": apiKey,
            "Accept": "text/event-stream",
        ]

        // 合并额外的请求头
        for (key, value) in additionalHeaders {
            headers[key] = value
        }

        // 构建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // 序列化请求体
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
        } catch {
            AppLogger.core.error("\(self.t)JSON 序列化失败：\(error.localizedDescription)")
            throw APIError.jsonSerializationFailed(underlying: error)
        }

        if Self.verbose {
            // 构建完整请求信息
            var logMessage = "\(self.t)🚀 发送流式请求到：\(url.absoluteString)\n"

            // 添加请求体
            if let bodyData = request.httpBody,
               let bodyString = String(data: bodyData, encoding: .utf8) {
                let bodySize = bodyData.count
                let formattedSize = Self.formatBytes(bodySize)
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
            for (key, value) in headers {
                // 隐藏敏感信息（以 "key" 结尾的字段）
                if key.lowercased().hasSuffix("key") {
                    logMessage += "  - \(key): ***\n"
                } else {
                    logMessage += "  - \(key): \(value)\n"
                }
            }

            AppLogger.core.info("\(logMessage)")
        }

        // 发送请求并处理流式响应
        let (bytes, response) = try await session.bytes(for: request)

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
        let chunkCallbackWarnThreshold: TimeInterval = 0.5
        let chunkCallbackHangWarnThresholdNs: UInt64 = 2000000000

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
                // 避免 Xcode 控制台缓存海量日志导致卡顿/内存上涨：只打印前几个块用于诊断
                if Self.verbose && chunkCount < 50 {
                    let decoded = String(data: eventData, encoding: .utf8) ?? "无法解码"
                    let preview = decoded.count > 300 ? String(decoded.prefix(300)) + "..." : decoded
                    AppLogger.core.info("\(self.t)📦 收到 SSE 数据块 #\(chunkCount) (\(eventData.count) bytes): \n\(preview)")
                }
                let callbackStart = CFAbsoluteTimeGetCurrent()
                let callbackChunkIndex = chunkCount
                let callbackBytes = eventData.count
                let loggerTag = self.t
                let hangWatchdog = Task.detached(priority: .utility) {
                    try? await Task.sleep(nanoseconds: chunkCallbackHangWarnThresholdNs)
                    guard !Task.isCancelled else { return }
                    AppLogger.core.error("\(loggerTag)⏳ onChunk 回调疑似卡住(>2s): chunk#\(callbackChunkIndex), bytes=\(callbackBytes)")
                }
                let shouldContinue = await onChunk(Data(eventData))
                hangWatchdog.cancel()
                let callbackElapsed = CFAbsoluteTimeGetCurrent() - callbackStart
                if callbackElapsed > chunkCallbackWarnThreshold {
                    AppLogger.core.error("\(self.t)⏱️ onChunk 回调耗时异常: \(String(format: "%.3f", callbackElapsed))s, chunk#\(chunkCount), bytes=\(eventData.count)")
                }
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
            let callbackStart = CFAbsoluteTimeGetCurrent()
            let remainingBytes = eventBuffer.count
            let loggerTag = self.t
            let hangWatchdog = Task.detached(priority: .utility) {
                try? await Task.sleep(nanoseconds: chunkCallbackHangWarnThresholdNs)
                guard !Task.isCancelled else { return }
                AppLogger.core.error("\(loggerTag)⏳ onChunk 回调疑似卡住(>2s): remaining bytes=\(remainingBytes)")
            }
            let shouldContinue = await onChunk(eventBuffer)
            hangWatchdog.cancel()
            let callbackElapsed = CFAbsoluteTimeGetCurrent() - callbackStart
            if callbackElapsed > chunkCallbackWarnThreshold {
                AppLogger.core.error("\(self.t)⏱️ onChunk 回调耗时异常(剩余块): \(String(format: "%.3f", callbackElapsed))s, bytes=\(eventBuffer.count)")
            }
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

    // MARK: - 带重试的原始请求

    private func sendRawRequestWithRetry(
        url: URL,
        method: HTTPMethod,
        headers: [String: String],
        body: [String: Any]?
    ) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 1 ... maxRetries {
            do {
                if Self.verbose && attempt > 1 {
                    AppLogger.core.info("\(self.t)🔄 重试 LLM 请求 (尝试 \(attempt)/\(self.maxRetries))")
                }

                let result = try await sendRawRequest(
                    url: url,
                    method: method,
                    headers: headers,
                    body: body
                )

                if Self.verbose && attempt > 1 {
                    AppLogger.core.info("\(self.t)✅ LLM 重试成功")
                }

                return result

            } catch {
                lastError = error

                if attempt < maxRetries && isRetryableError(error) {
                    let delay = calculateRetryDelay(for: attempt)
                    AppLogger.core.info("\(self.t)⚠️ LLM 请求失败 (\(error.localizedDescription))，\(Int(delay)) 秒后重试...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1000000000))
                } else {
                    if Self.verbose {
                        AppLogger.core.info("\(self.t)❌ LLM 请求最终失败：\(error.localizedDescription)")
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
            AppLogger.core.info("\(self.t)LLM 请求头:")
            for (key, value) in headers {
                let maskedValue = key.lowercased().contains("key") || key.lowercased().contains("auth")
                    ? String(value.prefix(10)) + "..."
                    : value
                AppLogger.core.info("\(self.t)  \(key): \(maskedValue)")
            }
        }

        if let body = body {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: body)
                request.httpBody = jsonData
            } catch {
                AppLogger.core.error("\(self.t)JSON 序列化失败：\(error.localizedDescription)")
                throw APIError.jsonSerializationFailed(underlying: error)
            }
        }

        if Self.verbose {
            AppLogger.core.info("\(self.t)发送 LLM \(method.rawValue) 请求到：\(url.absoluteString)")
        }

        do {
            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)

            if Self.verbose {
                AppLogger.core.info("\(self.t)LLM 请求成功，收到 \(data.count) 字节数据")
            }

            return (data, response)

        } catch let error as APIError {
            throw error
        } catch {
            AppLogger.core.error("\(self.t)LLM 请求失败：\(error.localizedDescription)")
            throw APIError.requestFailed(underlying: error)
        }
    }

    // MARK: - 错误判断

    /// 判断错误是否可重试
    private func isRetryableError(_ error: Error) -> Bool {
        switch error {
        case let APIError.requestFailed(underlying):
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

        case let APIError.httpError(statusCode, _):
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
        let jitter = Double.random(in: 0 ... 0.5)
        return delay + jitter
    }

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

    // MARK: - 辅助方法

    /// 格式化字节大小为人类可读的字符串
    /// - Parameter bytes: 字节数
    /// - Returns: 格式化后的字符串，如 "1.5 MB" 或 "500 bytes"
    private nonisolated static func formatBytes(_ bytes: Int) -> String {
        let kb = 1024
        let mb = kb * 1024
        let gb = mb * 1024

        if bytes >= gb {
            return String(format: "%.2f GB", Double(bytes) / Double(gb))
        } else if bytes >= mb {
            return String(format: "%.2f MB", Double(bytes) / Double(mb))
        } else if bytes >= kb {
            return String(format: "%.2f KB", Double(bytes) / Double(kb))
        } else {
            return "\(bytes) bytes"
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
