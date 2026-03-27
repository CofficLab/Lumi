import Foundation

/// LLM 请求元数据
///
/// 纯 HTTP 请求元数据，仅描述传输层信息。
struct RequestMetadata: Sendable {
    /// 请求唯一 ID
    let requestId: UUID
    /// HTTP 方法（GET/POST/...）
    let method: String
    /// 请求 URL
    let url: String
    /// 请求头（已脱敏）
    let requestHeaders: [String: String]
    /// 请求体大小（字节）
    let requestBodySizeBytes: Int
    /// 请求体预览（截断）
    let requestBodyPreview: String?
    /// 发送时间
    let sentAt: Date

    /// 响应状态码（如可获得）
    var responseStatusCode: Int?
    /// 响应头（如可获得）
    var responseHeaders: [String: String]?
    /// 响应耗时（秒）
    var duration: TimeInterval?
    /// 错误（如果失败）
    var error: Error?
    
    // MARK: - 计算属性
    
    /// 人类友好的请求体大小字符串（如 "1.5 MB"、"500 KB"）
    var formattedBodySize: String {
        let bodySizeBytes = requestBodySizeBytes
        let kb = 1024
        let mb = kb * 1024
        let gb = mb * 1024
        
        if bodySizeBytes >= gb {
            return String(format: "%.2f GB", Double(bodySizeBytes) / Double(gb))
        } else if bodySizeBytes >= mb {
            return String(format: "%.2f MB", Double(bodySizeBytes) / Double(mb))
        } else if bodySizeBytes >= kb {
            return String(format: "%.2f KB", Double(bodySizeBytes) / Double(kb))
        } else {
            return "\(bodySizeBytes) bytes"
        }
    }
    
    /// 是否成功
    var isSuccess: Bool {
        error == nil
    }
}
