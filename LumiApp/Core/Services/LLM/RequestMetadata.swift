import Foundation

/// LLM 请求元数据
///
/// 包含发送给 LLM 的完整请求信息，用于日志、审计和分析。
struct RequestMetadata: Sendable {
    // MARK: - 基础信息（原有）
    
    /// 请求体大小（字节）
    let bodySizeBytes: Int
    /// 请求 URL
    let url: String
    /// 发送时间戳
    let timestamp: Date
    
    // MARK: - 请求上下文（新增）
    
    /// 最终发送给 LLM 的完整消息列表
    let messages: [ChatMessage]?
    /// LLM 配置
    let config: LLMConfig?
    /// 可用的工具列表
    let tools: [AgentTool]?
    /// 临时系统提示词（RAG 等中间件添加的）
    let transientPrompts: [String]?
    
    // MARK: - 响应信息（响应后填充）
    
    /// 响应消息
    var responseMessage: ChatMessage?
    /// 响应耗时（秒）
    var duration: TimeInterval?
    /// Token 使用情况
    var tokenUsage: TokenUsage?
    /// 错误信息（如果请求失败）
    var error: Error?
    
    // MARK: - 计算属性
    
    /// 人类友好的请求体大小字符串（如 "1.5 MB"、"500 KB"）
    var formattedBodySize: String {
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
        error == nil && responseMessage != nil
    }
}

/// Token 使用情况
struct TokenUsage: Sendable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}
