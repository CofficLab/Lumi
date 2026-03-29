import Foundation

// MARK: - Zhipu API 响应模型

/// Zhipu API 响应结构
///
/// Zhipu AI 的响应格式兼容 Anthropic 格式。
/// 用于解析非流式响应。
///
/// 注意：流式响应直接复用 AnthropicProvider 的解析逻辑，
/// 因此不需要单独定义流式响应模型。
struct ZhipuResponse: Decodable {
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
        /// 使用 AnthropicProvider 中定义的 AnySendable 类型
        let input: [String: AnySendable]?
    }
}