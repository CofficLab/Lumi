import Foundation
import KitAgentTool
import KitLLM

extension LLMFunctionSchema {
    /// 从一个 Agent 工具构建 schema 描述。
    ///
    /// 若工具实现了 `NormalizedSchemaProviding`（如 MCP 工具），把它的
    /// 规范化文本一并带上，后续的 token 估算就不必再序列化一遍
    /// （Issue #1275）。
    ///
    /// `NormalizedSchemaProviding` 定义在 `KitLLM`（与 `LLMFunctionSchema`
    /// 同包），因此这里可以直接探测。
    public init(tool: any SuperAgentTool, language: LanguagePreference) {
        let parameters = tool.inputSchema(for: language)
        let normalized: String?
        if let providing = tool as? any NormalizedSchemaProviding {
            normalized = providing.normalizedInputSchemaJSON
        } else {
            normalized = nil
        }
        self.init(
            name: tool.name,
            description: tool.description(for: language),
            parameters: parameters,
            normalizedParametersJSON: normalized
        )
    }
}
