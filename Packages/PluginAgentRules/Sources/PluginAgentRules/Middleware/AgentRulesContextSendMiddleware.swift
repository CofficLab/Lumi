import Foundation
import SuperLogKit
import AgentToolKit
import os
import LumiCoreKit

/// Agent 规则上下文注入中间件
///
/// 在每次发送用户消息前，自动读取当前项目的规则列表，
/// 将规则摘要注入到 LLM 的提示词中，让大模型知晓当前项目有哪些可用规则。
///
/// ## 工作流程
/// 1. 拦截用户消息发送
/// 2. 从上下文获取当前项目路径
/// 3. 调用 AgentRulesService 读取规则列表
/// 4. 将规则摘要格式化为系统提示词
/// 5. 注入到 transientSystemPrompts 中
///
/// ## 设计决策
/// - 仅注入规则元数据（标题、描述），不注入完整内容，控制 token 消耗
/// - 大模型可通过 `list_agent_rules` / `create_agent_rule` 工具按需读取完整内容
/// - 如果规则目录不存在或为空，静默跳过，不阻塞发送流程
@MainActor
public final class AgentRulesContextSuperSendMiddleware: SuperSendMiddleware, SuperLog {
    public nonisolated static let emoji = "📜"
    public nonisolated static let verbose: Bool = true
    public let id: String = "agent-rules-context"
    public let order: Int = 0

    // MARK: - 执行

    public func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let projectPath = AgentRulesRuntime.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)

        if Self.verbose {
            if AgentRulesPlugin.verbose {
                            AgentRulesPlugin.logger.info("\(Self.t)📜 Agent Rules 上下文中间件：检查项目路径")
            }
            if AgentRulesPlugin.verbose {
                            AgentRulesPlugin.logger.info("\(Self.t)   项目路径：\(projectPath.isEmpty ? "<未选择>" : projectPath)")
            }
        }

        // 未选择项目时跳过
        guard !projectPath.isEmpty else {
            if Self.verbose {
                if AgentRulesPlugin.verbose {
                                    AgentRulesPlugin.logger.info("\(Self.t)   ⏭️ 跳过 (未选择项目)")
                }
            }
            await next(ctx)
            return
        }

        // 读取规则列表
        do {
            let rules = try await AgentRulesService.shared.listRules(projectPath: projectPath)

            // 无规则时跳过
            guard !rules.isEmpty else {
                if Self.verbose {
                    if AgentRulesPlugin.verbose {
                                            AgentRulesPlugin.logger.info("\(Self.t)   ⏭️ 跳过 (无规则)")
                    }
                }
                await next(ctx)
                return
            }

            // 构建规则摘要提示词
            let prompt = buildRulesPrompt(
                rules: rules,
                languagePreference: AgentRulesRuntime.languagePreference
            )
            ctx.transientSystemPrompts.append(prompt)

            if Self.verbose {
                if AgentRulesPlugin.verbose {
                                    AgentRulesPlugin.logger.info("\(Self.t)   ✅ 已注入 \(rules.count) 条规则摘要")
                }
                if AgentRulesPlugin.verbose {
                                    AgentRulesPlugin.logger.info("\(Self.t)   📝 提示词长度：\(prompt.count) 字符")
                }
            }
        } catch {
            // 规则目录不存在时静默跳过
            if Self.verbose {
                if AgentRulesPlugin.verbose {
                                    AgentRulesPlugin.logger.info("\(Self.t)   ⏭️ 跳过 (读取失败：\(error.localizedDescription))")
                }
            }
        }

        await next(ctx)
    }

    // MARK: - 提示词构建

    /// 将规则列表格式化为系统提示词
    private func buildRulesPrompt(
        rules: [AgentRuleMetadata],
        languagePreference: LanguagePreference
    ) -> String {
        switch languagePreference {
        case .chinese:
            return buildChineseRulesPrompt(rules: rules)
        case .english:
            return buildEnglishRulesPrompt(rules: rules)
        }
    }

    private func buildEnglishRulesPrompt(rules: [AgentRuleMetadata]) -> String {
        var lines: [String] = []

        lines.append("## Current Project Rules")
        lines.append("")
        lines.append("The current project has \(rules.count) rule document(s) in `.agent/rules/` that define coding standards, conventions, and best practices. You should read and follow these rules when working on this project.")
        lines.append("")
        lines.append("| Rule | Description |")
        lines.append("|------|-------------|")

        for rule in rules {
            // 转义 Markdown 表格中的竖线
            let escapedDescription = rule.description
                .replacingOccurrences(of: "|", with: "\\|")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            lines.append("| \(rule.title) | \(escapedDescription) |")
        }

        lines.append("")
        lines.append("You can use `list_agent_rules` to list all rules, or `create_agent_rule` to create a new rule. Read specific rules when they are relevant to the current task.")

        return lines.joined(separator: "\n")
    }

    private func buildChineseRulesPrompt(rules: [AgentRuleMetadata]) -> String {
        var lines: [String] = []

        lines.append("## 当前项目规则")
        lines.append("")
        lines.append("当前项目在 `.agent/rules/` 中有 \(rules.count) 个规则文档，定义了编码标准、约定和最佳实践。处理该项目时应读取并遵循这些规则。")
        lines.append("")
        lines.append("| 规则 | 描述 |")
        lines.append("|------|------|")

        for rule in rules {
            let escapedDescription = rule.description
                .replacingOccurrences(of: "|", with: "\\|")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            lines.append("| \(rule.title) | \(escapedDescription) |")
        }

        lines.append("")
        lines.append("你可以使用 `list_agent_rules` 列出所有规则，或使用 `create_agent_rule` 创建新规则。当前任务相关时，请读取具体规则。")

        return lines.joined(separator: "\n")
    }
}
