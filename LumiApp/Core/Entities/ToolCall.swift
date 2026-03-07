import Foundation

/// 工具调用模型
///
/// 表示 AI 助手请求执行工具/函数的调用。
/// 当 AI 分析用户请求后认为需要执行某个工具时，会生成 ToolCall。
///
/// ## 工作流程
///
/// ```text
/// 1. 用户发送消息
/// 2. AI 分析请求
/// 3. AI 返回 ToolCall（而非直接回复）
/// 4. 系统执行工具函数
/// 5. 工具结果返回给 AI
/// 6. AI 根据结果生成最终回复
/// ```
///
/// ## 使用示例
///
/// ```swift
/// // AI 请求执行文件读取工具
/// let toolCall = ToolCall(
///     id: "call_abc123",
///     name: "read_file",
///     arguments: "{\"path\": \"/Users/angel/test.swift\"}"
/// )
/// ```
struct ToolCall: Codable, Sendable, Equatable {
    /// 工具调用唯一标识符
    ///
    /// 用于关联请求和响应。
    /// 格式通常为 "call_" 开头加上随机字符串。
    let id: String
    
    /// 工具名称
    ///
    /// 要执行的工具/函数名称。
    /// 对应 AgentTool 中定义的工具。
    /// 例如："read_file", "write_file", "run_command"
    let name: String
    
    /// 工具参数（JSON 字符串）
    ///
    /// 工具执行所需的参数，以 JSON 格式编码。
    /// 需要解析为对应工具的参数类型。
    let arguments: String
}