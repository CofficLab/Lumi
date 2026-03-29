import Foundation

// MARK: - Aliyun API 响应模型

/// Aliyun API 响应结构
///
/// 阿里云 DashScope Coding Plan 的响应格式兼容 Anthropic 格式。
/// 用于解析非流式响应。
///
/// 注意：流式响应在 AliyunProvider 中直接处理，
/// 因此不需要单独定义流式响应模型。
struct AliyunResponse: Decodable {
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
        let input: [String: AliyunAnySendable]?
    }
}

// MARK: - 辅助类型

/// 任意类型解码器
///
/// 用于处理 API 响应中类型不确定的字段。
/// Aliyun 的 tool_use.input 字段类型可能是任意 JSON 类型。
struct AliyunAnySendable: Decodable {
    /// 存储的任意类型值
    let value: Any
    
    /// 从 Decoder 解码
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let dictValue = try? container.decode([String: AliyunAnySendable].self) {
            value = dictValue.mapValues { $0.value }
        } else if let arrayValue = try? container.decode([AliyunAnySendable].self) {
            value = arrayValue.map { $0.value }
        } else {
            value = ""
        }
    }
    
    /// 直接初始化
    init(value: Any) {
        self.value = value
    }
}