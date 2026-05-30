import AgentToolKit
import LumiCoreKit
import PluginAgentRAG
import RAGKit
import SuperLogKit
import SwiftUI

actor AgentRAGPlugin: SuperPlugin {
    nonisolated static let logger = PluginAgentRAG.RAGPlugin.logger
    nonisolated static let emoji = PluginAgentRAG.RAGPlugin.emoji
    nonisolated static let verbose = PluginAgentRAG.RAGPlugin.verbose
    static let id = PluginAgentRAG.RAGPlugin.id
    static let displayName = PluginAgentRAG.RAGPlugin.displayName
    static let description = PluginAgentRAG.RAGPlugin.description
    static let iconName = PluginAgentRAG.RAGPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginAgentRAG.RAGPlugin.category) }
    static var order: Int { PluginAgentRAG.RAGPlugin.order }
    static let shared = AgentRAGPlugin()

    private let packaged = PluginAgentRAG.RAGPlugin.shared

    init() {
        PluginAgentRAG.RAGPluginRuntime.databaseDirectoryProvider = {
            AppConfig.getPluginDBFolderURL(pluginName: "RAGPlugin")
        }
    }

    nonisolated func onEnable() {
        PluginAgentRAG.RAGPlugin.shared.onEnable()
    }

    @MainActor
    func addPosterViews() -> [AnyView] {
        packaged.addPosterViews()
    }

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(AppRAGSendMiddleware())]
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        packaged.agentTools(context: context.packageContext)
    }

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(RAGRuntimeBridge(content: content()))
    }

    @MainActor
    func addSettingsView() -> AnyView? {
        AnyView(PluginAgentRAG.RAGSettingsView())
    }

    @MainActor
    func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        return AnyView(PluginAgentRAG.RAGStatusBarView())
    }
}

@MainActor
private struct RAGRuntimeBridge<Content: View>: View {
    let content: Content

    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
        PluginAgentRAG.RAGAutoIndexOverlay(content: content)
            .onAppear(perform: sync)
            .onChange(of: projectVM.currentProjectPath) { _, _ in sync() }
    }

    private func sync() {
        let path = projectVM.currentProjectPath
        let project = path.isEmpty ? nil : PluginAgentRAG.RAGRuntimeProject(
            name: projectVM.currentProjectName.isEmpty ? URL(fileURLWithPath: path).lastPathComponent : projectVM.currentProjectName,
            path: path
        )
        PluginAgentRAG.RAGPluginRuntime.currentProjectProvider = { project }
        PluginAgentRAG.RAGPluginRuntime.recentProjectsProvider = { project.map { [$0] } ?? [] }
    }
}

@MainActor
private final class AppRAGSendMiddleware: SuperSendMiddleware, SuperLog {
    nonisolated static let logger = PluginAgentRAG.RAGPlugin.logger
    nonisolated static let emoji = "RAG"
    nonisolated static let verbose = true

    let id = "rag"
    let order = 100

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let userMessage = ctx.message.content
        let projectPath = ctx.projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard RAGIntentAnalyzer.shouldUseRAG(for: userMessage), !projectPath.isEmpty else {
            await next(ctx)
            return
        }

        let ragService = PluginAgentRAG.RAGPlugin.getService()
        guard ragService.isInitialized,
              !RAGService.isAnyIndexing(),
              !RAGService.isIndexing(projectPath: projectPath) else {
            await next(ctx)
            return
        }

        do {
            if try await ragService.checkNeedsIndex(projectPath: projectPath) {
                await ragService.ensureIndexedBackground(projectPath: projectPath)
                await next(ctx)
                return
            }

            let response = try await ragService.retrieve(
                query: userMessage,
                projectPath: projectPath,
                topK: 5
            )
            if response.hasResults {
                let languagePreference: RAGLanguagePreference = ctx.projectVM.languagePreference == .chinese ? .chinese : .english
                ctx.transientSystemPrompts.append(
                    RAGContextBuilder.buildPrompt(
                        query: userMessage,
                        results: response.results,
                        projectPath: projectPath,
                        languagePreference: languagePreference
                    )
                )
            }
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)RAG retrieval failed: \(error.localizedDescription)")
            }
        }

        await next(ctx)
    }
}
