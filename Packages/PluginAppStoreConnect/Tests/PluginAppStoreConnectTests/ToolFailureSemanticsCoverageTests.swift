import Foundation
import KitAgentTool
import Testing
@testable import PluginAppStoreConnect

/// 回归 #861：App Store Connect 工具把失败标记成成功。
///
/// 工具失败有两种表达方式：抛出 `ToolExecutionError`（ToolManager 会记成
/// `.failed`）或返回 `ToolCallResult(isError: true)`。若失败只用一段普通文本
/// 返回，默认的 `executeResult` 会把它包成 `isError == false` 的成功结果：
/// 执行记录、Job 状态与日志全都显示成功，Agent 也会继续往下走。
///
/// 这些测试逐个覆盖插件注册的 27 个工具：缺少必填参数时必须以失败表达。
@MainActor
@Suite("App Store Connect 工具失败语义（全量）")
struct ToolFailureSemanticsCoverageTests {

    /// 插件注册的全部 Agent 工具。
    private var allTools: [any SuperAgentTool] {
        AppStoreConnectPlugin.agentTools
    }

    @Test("插件注册了 27 个 Agent 工具")
    func registersAllTools() {
        #expect(allTools.count == 27)
    }

    @Test("缺少必填参数时每个工具都以失败表达")
    func everyToolReportsMissingArgumentsAsFailure() async {
        for tool in allTools {
            await #expect(throws: ToolExecutionError.self, "\(tool.name) 未把缺失参数标记为失败") {
                _ = try await tool.executeResult(arguments: [:])
            }
        }
    }

    @Test("空白参数等同于缺失，每个工具都以失败表达")
    func everyToolReportsBlankArgumentsAsFailure() async {
        for tool in allTools {
            let blankArguments = blankArguments(for: tool)
            await #expect(throws: ToolExecutionError.self, "\(tool.name) 未把空白参数标记为失败") {
                _ = try await tool.executeResult(arguments: blankArguments)
            }
        }
    }

    /// 为工具的每个必填参数填一个空白字符串。
    ///
    /// 从 `inputSchema` 读取 `required`，避免测试与 schema 悄悄漂移。
    private func blankArguments(for tool: any SuperAgentTool) -> [String: ToolArgument] {
        let schema = tool.inputSchema(for: .english)
        guard let properties = schema["properties"] as? [String: Any],
              let required = schema["required"] as? [String] else {
            return [:]
        }

        var arguments: [String: ToolArgument] = [:]
        for key in required {
            let type = (properties[key] as? [String: Any])?["type"] as? String
            // 整数参数用空白字符串同样属于非法值（解析不出来即视为缺失）。
            arguments[key] = ToolArgument(type == "integer" ? " " : "   ")
        }
        return arguments
    }
}
