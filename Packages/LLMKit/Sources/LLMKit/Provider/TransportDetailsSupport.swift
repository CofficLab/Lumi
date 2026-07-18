import Foundation
import HttpKit

/// 传输详情工具函数
///
/// 提供统一的传输详情格式化逻辑，用于错误消息和调试。
public enum TransportDetailsSupport {
    
    /// 构建传输详情字符串
    ///
    /// - Parameters:
    ///   - request: HTTP 请求
    ///   - requestBody: 请求体
    ///   - state: 流式状态（可选）
    /// - Returns: 格式化的传输详情字符串
    public static func transportDetails(
        request: URLRequest,
        requestBody: [String: Any],
        state: StreamingState?
    ) async -> String {
        var lines: [String] = []
        lines.append("Request URL: \(request.url?.absoluteString ?? "-")")
        lines.append("Request Method: \(request.httpMethod ?? "POST")")
        lines.append("Request Headers:")
        lines.append(prettyHeaders(maskedHeaders(request.allHTTPHeaderFields ?? [:])))
        lines.append("Request Body:")
        lines.append(LLMTransportDetails.truncatedBodyForDisplay(prettyJSON(requestBody)))
        
        if let state {
            let status = await state.httpStatusCode
            let responseHeaders = await state.httpResponseHeaders ?? [:]
            let responseBody = await state.httpResponseBody ?? "-"
            lines.append("Response Status: \(status.map(String.init) ?? "-")")
            lines.append("Response Headers:")
            lines.append(prettyHeaders(maskedHeaders(responseHeaders)))
            lines.append("Response Body:")
            lines.append(LLMTransportDetails.truncatedBodyForDisplay(responseBody))
        }
        return lines.joined(separator: "\n")
    }
    
    /// 将传输详情附加到错误摘要
    ///
    /// - Parameters:
    ///   - summary: 错误摘要
    ///   - request: HTTP 请求
    ///   - requestBody: 请求体
    ///   - state: 流式状态（可选）
    /// - Returns: 带传输详情的完整错误消息
    public static func attachTransportDetails(
        summary: String,
        request: URLRequest,
        requestBody: [String: Any],
        state: StreamingState?
    ) async -> String {
        let details = await transportDetails(
            request: request,
            requestBody: requestBody,
            state: state
        )
        guard !details.isEmpty else { return summary }
        return summary + "\n\n--- Request / Response Details ---\n" + details
    }
    
    /// 从 HTTP 响应中提取规范化头信息
    ///
    /// - Parameter response: HTTP URL 响应
    /// - Returns: 规范化的头信息字典
    public static func normalizedHeaders(from response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let key = key as? String else { continue }
            headers[key] = String(describing: value)
        }
        return headers
    }
    
    /// 掩码敏感头信息
    ///
    /// - Parameter headers: 原始头信息
    /// - Returns: 掩码后的头信息
    public static func maskedHeaders(_ headers: [String: String]) -> [String: String] {
        var masked = headers
        for (key, value) in headers {
            let lower = key.lowercased()
            if lower == "authorization" || lower == "x-api-key" || lower.contains("token") || lower.contains("api-key") {
                masked[key] = maskSecret(value)
            }
        }
        return masked
    }
    
    /// 掩码密钥值
    ///
    /// - Parameter value: 原始值
    /// - Returns: 掩码后的值
    public static func maskSecret(_ value: String) -> String {
        guard value.count > 8 else { return "***" }
        let prefix = value.prefix(4)
        let suffix = value.suffix(4)
        return "\(prefix)***\(suffix)"
    }
    
    /// 格式化头信息为可读字符串
    ///
    /// - Parameter headers: 头信息字典
    /// - Returns: 格式化的字符串
    public static func prettyHeaders(_ headers: [String: String]) -> String {
        guard !headers.isEmpty else { return "-" }
        return headers.keys.sorted().map { "\($0): \(headers[$0] ?? "")" }.joined(separator: "\n")
    }
    
    /// 格式化 JSON 为可读字符串
    ///
    /// - Parameter body: JSON 对象
    /// - Returns: 格式化的 JSON 字符串
    public static func prettyJSON(_ body: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "-"
        }
        return text
    }
}
