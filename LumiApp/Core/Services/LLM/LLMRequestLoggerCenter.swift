import Foundation

/// LLM 请求日志接口，由插件实现，内核只依赖此协议
protocol LLMRequestLogging: Sendable {
    func log(
        providerId: String,
        model: String,
        url: URL,
        method: String,
        statusCode: Int?,
        durationMs: Double?,
        requestBody: Data?,
        responseBody: Data?,
        error: Error?
    )
}

/// LLM 请求日志分发中心（内核级别，可选，无日志实现时为 no-op）
final class LLMRequestLoggerCenter: @unchecked Sendable {
    static let shared = LLMRequestLoggerCenter()

    private let queue = DispatchQueue(label: "LLMRequestLoggerCenter.queue", qos: .userInitiated)
    private var logger: (any LLMRequestLogging)?

    private init() {}

    /// 由插件注册具体的日志实现
    func register(logger: any LLMRequestLogging) {
        queue.async { [weak self] in
            self?.logger = logger
        }
    }

    /// 可选：在插件被卸载或禁用时清除实现
    func clearLogger() {
        queue.async { [weak self] in
            self?.logger = nil
        }
    }

    /// 供内核调用的日志入口（若没有实现则直接返回）
    func log(
        providerId: String,
        model: String,
        url: URL,
        method: String,
        statusCode: Int?,
        durationMs: Double?,
        requestBody: Data?,
        responseBody: Data?,
        error: Error?
    ) {
        let currentLogger: (any LLMRequestLogging)? = queue.sync { logger }
        currentLogger?.log(
            providerId: providerId,
            model: model,
            url: url,
            method: method,
            statusCode: statusCode,
            durationMs: durationMs,
            requestBody: requestBody,
            responseBody: responseBody,
            error: error
        )
    }
}

