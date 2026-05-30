import AgentToolKit
import LumiCoreKit
import PluginAgentRules
import SwiftUI

actor AgentRulesPlugin: SuperPlugin {
    nonisolated static let logger = PluginAgentRules.AgentRulesPlugin.logger
    nonisolated static let emoji = PluginAgentRules.AgentRulesPlugin.emoji
    nonisolated static let verbose = PluginAgentRules.AgentRulesPlugin.verbose
    static let id = PluginAgentRules.AgentRulesPlugin.id
    static let displayName = PluginAgentRules.AgentRulesPlugin.displayName
    static let description = PluginAgentRules.AgentRulesPlugin.description
    static let iconName = PluginAgentRules.AgentRulesPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginAgentRules.AgentRulesPlugin.category) }
    static var order: Int { PluginAgentRules.AgentRulesPlugin.order }
    static let shared = AgentRulesPlugin()

    private let packaged = PluginAgentRules.AgentRulesPlugin.shared

    @MainActor
    func addPosterViews() -> [AnyView] {
        packaged.addPosterViews()
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        packaged.agentTools(context: context.packageContext)
    }

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(AgentRulesRuntimeBridge(content: content()))
    }

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(AppAgentRulesMiddleware())]
    }
}

@MainActor
private struct AgentRulesRuntimeBridge<Content: View>: View {
    let content: Content

    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
        content
            .onAppear(perform: sync)
            .onChange(of: projectVM.currentProjectPath) { _, _ in sync() }
            .onChange(of: projectVM.languagePreference) { _, _ in sync() }
    }

    private func sync() {
        PluginAgentRules.AgentRulesRuntime.currentProjectPathProvider = { projectVM.currentProjectPath }
        PluginAgentRules.AgentRulesRuntime.languagePreferenceProvider = { projectVM.languagePreference }
    }
}

@MainActor
private final class AppAgentRulesMiddleware: SuperSendMiddleware {
    let id = "agent-rules-context"
    let order = 0

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let projectPath = ctx.projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else {
            await next(ctx)
            return
        }

        do {
            let rules = try await PluginAgentRules.AgentRulesService.shared.listRules(projectPath: projectPath)
            if !rules.isEmpty {
                ctx.transientSystemPrompts.append(
                    Self.buildRulesPrompt(rules: rules, languagePreference: ctx.projectVM.languagePreference)
                )
            }
        } catch {
            // Missing or unreadable rule folders should not block sending.
        }

        await next(ctx)
    }

    private static func buildRulesPrompt(
        rules: [PluginAgentRules.AgentRuleMetadata],
        languagePreference: LanguagePreference
    ) -> String {
        switch languagePreference {
        case .chinese:
            return """
            ## 当前项目规则

            当前项目在 `.agent/rules/` 中有 \(rules.count) 个规则文档，处理该项目时应读取并遵循这些规则。

            \(rules.map { "- \($0.title): \($0.description)" }.joined(separator: "\n"))
            """
        case .english:
            return """
            ## Current Project Rules

            The current project has \(rules.count) rule document(s) in `.agent/rules/`. Read and follow these rules when working on this project.

            \(rules.map { "- \($0.title): \($0.description)" }.joined(separator: "\n"))
            """
        }
    }
}
