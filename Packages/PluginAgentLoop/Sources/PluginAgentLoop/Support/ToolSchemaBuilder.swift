import Foundation
import KitAgentTool
import KitLLM
import ProviderLLMContext

/// 工具 schema 的组装与 token 估算。
///
/// ## 为什么独立成类型
///
/// 这两件事原先是 `AgentLoopManager` 上的实例方法，但它们**不依赖任何
/// manager 状态**——纯粹是「一组工具 → schema 数组 / token 数」的纯函数式
/// 计算。独立成类型后：
///
/// 1. 可以被直接测试，不必构造整个 manager；
/// 2. 组装可以在后台线程执行（`Task.detached`），不占住主线程；
/// 3. 规范化文本的复用逻辑集中在一处。
///
/// ## 关于主线程
///
/// 工具数量随启用的 MCP 服务器增长（GitHub preset 约 130 个），组装要逐个
/// 取 `inputSchema`、算描述。放在主线程上会挤占流式渲染的时间
/// （Issue #1275）。
///
/// 必须用 `Task.detached`：实测直接调用 `nonisolated` 静态函数与
/// `Task {}`（继承 actor 上下文）**都仍在主线程上执行**，只有
/// `Task.detached` 才会真正离开。
public enum ToolSchemaBuilder {

    /// 在后台线程组装工具 schema 数组。
    ///
    /// - Parameters:
    ///   - tools: 待组装的工具。
    ///   - language: 描述文案的语言。
    /// - Returns: schema 数组。
    public static func buildSchemas(
        _ tools: [any SuperAgentTool],
        language: LanguagePreference
    ) async -> [LLMFunctionSchema] {
        await Task.detached(priority: .userInitiated) {
            tools.map { tool in
                LLMFunctionSchema(tool: tool, language: language)
            }
        }.value
    }

    /// 估算全部工具 schema 占用的 token 数，用于上下文预算的保守预留。
    ///
    /// schema 若已带规范化文本（`normalizedParametersJSON`，MCP 工具在
    /// 注册时就备好了），直接用它，不再把刚解析好的字典序列化回去——
    /// 那一步的成本与解析本身相当（Issue #1275）。
    public static func estimateTokens(_ schemas: [LLMFunctionSchema]) -> Int {
        schemas.reduce(0) { total, schema in
            let parameters = schema.normalizedParametersJSON
                ?? jsonText(for: schema.parameters)
            return total
                + LLMContextTokenEstimator.estimate(text: schema.name)
                + LLMContextTokenEstimator.estimate(text: schema.description)
                + LLMContextTokenEstimator.estimate(text: parameters)
                + 16
        }
    }

    /// 把工具参数序列化为键序稳定的 JSON 文本，供 token 估算使用。
    ///
    /// - Important: 必须先用 `isValidJSONObject` 预检，不能只靠 `try?`。
    ///   `JSONSerialization.data(withJSONObject:)` 遇到非 JSON 类型（闭包、
    ///   `Date`、`Data`、`NaN` 等）时抛的是 ObjC `NSException` 而非 Swift
    ///   `Error`，`try?` 捕获不到，会直接 abort 整个进程（signal 6）。
    ///   因此畸形工具 schema 必须先降级为文本估算，而不是让回合崩溃。
    public static func jsonText(for parameters: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(parameters),
              let data = try? JSONSerialization.data(
                withJSONObject: parameters,
                options: [.sortedKeys]
              ),
              let text = String(data: data, encoding: .utf8)
        else {
            return String(describing: parameters)
        }
        return text
    }
}
