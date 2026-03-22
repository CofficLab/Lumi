import Foundation

struct AgentConfig {
    // 最大深度
    static let maxDepth = 60
    
    // 最大工具结果长度
    static let maxToolResultLength = 4000

    // 连续重复同一工具签名（名称+参数）达到多少次视为循环
    static let repeatedToolSignatureThreshold = 10

    // 在最近窗口中同一签名出现多少次视为循环
    static let repeatedToolWindowThreshold = 10

    // 最大 thinking 文本长度
    static let maxThinkingTextLength = 100000

    // 流式 UI 刷新间隔
    static let streamUIFlushInterval: TimeInterval = 0.08

    // thinking UI 刷新间隔
    static let thinkingUIFlushInterval: TimeInterval = 0.12

    // 流式立即刷新字符数
    static let immediateStreamFlushChars = 80

    // thinking 立即刷新字符数
    static let immediateThinkingFlushChars = 120
}