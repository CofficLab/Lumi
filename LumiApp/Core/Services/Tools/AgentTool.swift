import Foundation

/// 工具风险等级元数据由插件定义，内核只消费结果。
import SwiftUI

/// 工具参数包装器
///
/// 用于在工具调用时传递参数的包装类型。
/// 使用 `@unchecked Sendable` 来抑制并发警告，
/// 因为参数值可能是任意类型。
public struct ToolArgument: @unchecked Sendable {
    /// 参数的实际值
    public let value: Any
    
    /// 初始化工具参数
    ///
    /// - Parameter value: 任意类型的参数值
    public init(_ value: Any) { self.value = value }
}

/// 代理工具协议
///
/// 定义 LLM 可以调用的工具/函数接口。
/// 工具允许 AI 助手执行特定操作，如读写文件、执行命令等。
///
/// ## 工具定义
///
/// 每个工具需要实现：
/// - `name`: 唯一名称，用于 AI 选择工具
/// - `description`: 功能描述，帮助 AI 理解何时使用
/// - `inputSchema`: 输入参数的 JSON Schema
/// - `execute`: 实际执行工具逻辑
///
/// ## 使用示例
///
/// ```swift
/// /// 读取文件工具
/// struct ReadFileTool: AgentTool {
///     let name = "read_file"
///     let description = "读取指定路径的文件内容"
///     
///     var inputSchema: [String: Any] {
///         [
///             "type": "object",
///             "properties": [
///                 "path": [
///                     "type": "string",
///                     "description": "文件路径"
///                 ]
///             ],
///             "required": ["path"]
///         ]
///     }
///     
///     func execute(arguments: [String: ToolArgument]) async throws -> String {
///         let path = arguments["path"]?.value as? String ?? ""
///         return try String(contentsOfFile: path)
///     }
/// }
/// ```
protocol AgentTool: Sendable {
    /// 工具名称
    ///
    /// 唯一标识符，AI 通过名称选择要执行的工具。
    /// 建议使用下划线命名法，如 "read_file", "run_command"
    var name: String { get }
    
    /// 工具描述
    ///
    /// 详细描述工具的功能、用途和使用场景。
    /// AI 根据描述判断是否需要调用此工具。
    /// 建议包含：
    /// - 工具用途
    /// - 输入参数含义
    /// - 返回值说明
    var description: String { get }
    
    /// 输入参数 JSON Schema
    ///
    /// 定义工具接受的参数格式。
    /// 使用 JSON Schema 格式，便于 AI 理解和生成正确参数。
    var inputSchema: [String: Any] { get }
    
    /// 执行工具
    ///
    /// 实际执行工具逻辑的方法。
    /// 接收参数字典，执行相应操作，返回结果字符串。
    ///
    /// - Parameter arguments: 符合 inputSchema 的参数字典
    /// - Returns: 执行结果，以字符串形式返回
    ///
    /// - Throws: 执行过程中可能抛出的错误
    func execute(arguments: [String: ToolArgument]) async throws -> String
}

extension AgentTool {
    /// 工具自行评估当前调用的风险等级。
    ///
    /// - Parameter arguments: 工具调用参数
    /// - Returns: 如果返回 nil，则表示“不声明风险”，由上层采用默认策略。
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel? {
        nil
    }
}

/// 工具参数定义辅助结构
///
/// 用于更方便地定义工具参数。
struct ToolParam {
    /// 参数类型
    ///
    /// JSON Schema 类型："string", "number", "boolean", "object", "array"
    let type: String
    
    /// 参数描述
    ///
    /// 说明参数的用途和含义
    let description: String
    
    /// 是否必需
    ///
    /// true 表示调用时必须提供此参数
    let required: Bool
}