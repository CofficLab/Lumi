import Foundation
import KitAgentTool
import Testing
@testable import BrowserPlugin

/// 工具描述的本地化测试。
///
/// 工具描述是 LLM 唯一的说明书，中英文都必须可用；写死英文会让中文会话里
/// 的工具列表出现混杂语言，降低模型理解的一致性。
@Suite("Browser 工具本地化")
@MainActor
struct BrowserToolLocalizationTests {
    /// 抽取出 inputSchema 里所有 description 字段。
    private func descriptions(in schema: [String: Any]) -> [String] {
        var out: [String] = []
        if let properties = schema["properties"] as? [String: Any] {
            for (_, value) in properties {
                if let dict = value as? [String: Any],
                   let description = dict["description"] as? String {
                    out.append(description)
                }
            }
        }
        return out
    }

    @Test("全部工具在中文偏好下返回中文描述")
    func allToolsDescribeInChinese() throws {
        let manager = BrowserSessionManager()
        let tools: [any SuperAgentTool] = [
            BrowserOpenTool(sessions: manager),
            BrowserSnapshotTool(sessions: manager),
            BrowserReadTool(sessions: manager),
            BrowserStatusTool(sessions: manager),
            BrowserInteractTool(sessions: manager),
            BrowserWaitTool(sessions: manager),
            BrowserScreenshotTool(sessions: manager),
            BrowserNavigateTool(sessions: manager),
            BrowserEvaluateTool(sessions: manager),
        ]

        for tool in tools {
            let description = tool.description(for: .chinese)
            #expect(!description.isEmpty, "\(tool.name) 中文描述为空")

            // 中文描述不应仍是英文原文。
            let english = tool.description(for: .english)
            if description != english {
                // 中文与英文不同才需要进一步校验语言。
                let hasChinese = description.range(of: "\\p{Han}", options: .regularExpression) != nil
                #expect(hasChinese, "\(tool.name) 的中文偏好未返回中文：\(description.prefix(60))")
            }
        }
    }

    @Test("全部工具的参数说明在中文偏好下返回中文")
    func allToolArgumentsDescribeInChinese() throws {
        let manager = BrowserSessionManager()
        let tools: [any SuperAgentTool] = [
            BrowserOpenTool(sessions: manager),
            BrowserSnapshotTool(sessions: manager),
            BrowserReadTool(sessions: manager),
            BrowserInteractTool(sessions: manager),
            BrowserWaitTool(sessions: manager),
            BrowserScreenshotTool(sessions: manager),
            BrowserNavigateTool(sessions: manager),
            BrowserEvaluateTool(sessions: manager),
        ]

        for tool in tools {
            let schema = tool.inputSchema(for: .chinese)
            let chineseDescriptions = descriptions(in: schema)
            let englishDescriptions = descriptions(in: tool.inputSchema(for: .english))
            #expect(chineseDescriptions.count == englishDescriptions.count, "\(tool.name) 中英文参数数量不一致")

            for description in chineseDescriptions where !description.isEmpty {
                let hasChinese = description.range(of: "\\p{Han}", options: .regularExpression) != nil
                #expect(hasChinese, "\(tool.name) 的中文参数说明未本地化：\(description.prefix(60))")
            }
        }
    }

    @Test("交互工具的动作枚举覆盖全部动作")
    func interactExposesEveryAction() {
        let manager = BrowserSessionManager()
        let tool = BrowserInteractTool(sessions: manager)
        let schema = tool.inputSchema(for: .english)

        guard let properties = schema["properties"] as? [String: Any],
              let action = properties["action"] as? [String: Any],
              let values = action["enum"] as? [String] else {
            Issue.record("缺少 action 枚举")
            return
        }

        #expect(values.count == BrowserInteractionAction.allCases.count)
        for expected in BrowserInteractionAction.allCases {
            #expect(values.contains(expected.rawValue), "动作 \(expected.rawValue) 未出现在 schema 中")
        }
    }
}
