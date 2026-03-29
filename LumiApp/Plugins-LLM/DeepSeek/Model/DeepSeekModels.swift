import Foundation

// MARK: - DeepSeek API 响应模型

/// DeepSeek API 响应结构
///
/// DeepSeek 的响应格式兼容 OpenAI 格式。
/// 用于解析非流式响应。
///
/// 注意：流式响应直接复用 OpenAIProvider 的解析逻辑，
/// 因此不需要单独定义流式响应模型。
struct DeepSeekResponse: Decodable {
    /// 响应选项列表
    let choices: [Choice]
    
    /// 响应选项
    struct Choice: Decodable {
        /// 消息内容
        let message: Message
        
        /// 消息结构
        struct Message: Decodable {
            /// 文本内容
            let content: String?
            
            /// 工具调用列表
            let tool_calls: [ToolCallData]?
            
            /// 工具调用数据
            struct ToolCallData: Decodable {
                /// 工具调用 ID
                let id: String
                
                /// 工具类型
                let type: String
                
                /// 函数信息
                let function: FunctionData
                
                /// 函数数据
                struct FunctionData: Decodable {
                    /// 函数名称
                    let name: String
                    
                    /// 函数参数（JSON 字符串）
                    let arguments: String
                }
            }
        }
    }
}