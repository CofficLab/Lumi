import Foundation

// MARK: - Anthropic API 响应模型

/// Anthropic API 响应结构
///
/// 用于解析非流式响应。
struct AnthropicResponse: Decodable {
    /// 响应内容块列表
    let content: [ContentBlock]
    
    /// 内容块类型
    struct ContentBlock: Decodable {
        /// 内容类型（text 或 tool_use）
        let type: String
        
        /// 文本内容（type 为 text 时）
        let text: String?
        
        /// 工具调用 ID（type 为 tool_use 时）
        let id: String?
        
        /// 工具名称（type 为 tool_use 时）
        let name: String?
        
        /// 工具输入参数（type 为 tool_use 时）
        let input: [String: AnySendable]?
    }
}

// MARK: - 辅助类型

/// 任意类型解码器
///
/// 用于处理 API 响应中类型不确定的字段。
/// Anthropic 的 tool_use.input 字段类型可能是任意 JSON 类型。
///
/// 注意：此类型被多个供应商共享使用（Zhipu、Aliyun、DeepSeek 等）。
struct AnySendable: Decodable {
    /// 存储的任意类型值
    let value: Any
    
    /// 从 Decoder 解码
    ///
    /// 尝试依次解码为：Int → Double → String → Bool → Array → Object
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // 尝试按优先级解码为具体类型
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let dictValue = try? container.decode([String: AnySendable].self) {
            value = dictValue.mapValues { $0.value }
        } else if let arrayValue = try? container.decode([AnySendable].self) {
            value = arrayValue.map { $0.value }
        } else {
            value = ""  // 默认空字符串
        }
    }
    
    /// 直接初始化
    init(value: Any) {
        self.value = value
    }
}