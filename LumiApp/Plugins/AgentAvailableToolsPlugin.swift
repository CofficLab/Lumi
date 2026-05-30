import AgentToolKit
import PluginEditorPanel
import LumiCoreKit
import LumiUI
import PluginAgentAvailableTools
import SwiftUI

actor AgentAvailableToolsPlugin: SuperPlugin {
    nonisolated static let emoji = PluginAgentAvailableTools.AgentAvailableToolsPlugin.emoji
    nonisolated static let verbose = PluginAgentAvailableTools.AgentAvailableToolsPlugin.verbose
    static let id = PluginAgentAvailableTools.AgentAvailableToolsPlugin.id
    static let displayName = PluginAgentAvailableTools.AgentAvailableToolsPlugin.displayName
    static let description = PluginAgentAvailableTools.AgentAvailableToolsPlugin.description
    static let iconName = PluginAgentAvailableTools.AgentAvailableToolsPlugin.iconName
    static var category: PluginCategory {
        PluginCategory(package: PluginAgentAvailableTools.AgentAvailableToolsPlugin.category)
    }
    static var order: Int { PluginAgentAvailableTools.AgentAvailableToolsPlugin.order }
    static let policy = PluginAgentAvailableTools.AgentAvailableToolsPlugin.policy
    static let shared = AgentAvailableToolsPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(AvailableToolsButton())
    }
}

private struct AvailableToolsButton: View {
    var body: some View {
        StatusBarHoverContainer(
            detailView: AvailableToolsListDetailView(),
            popoverWidth: 680,
            id: "available-tools-status"
        ) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.appMicroEmphasized)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
    }
}

private struct AvailableToolsListDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject var conversationTurnServices: AppConversationTurnVM
    @State private var query = ""
    @State private var selectedLanguage: LanguagePreference = .english

    private var tools: [SuperAgentTool] {
        conversationTurnServices.toolService.allTools
    }

    var body: some View {
        StatusBarPopoverScaffold(
            title: String(localized: "Tools", table: "AgentAvailableToolsPlugin"),
            systemImage: "wrench.and.screwdriver",
            subtitle: toolsCountText
        ) {
            HStack(spacing: 10) {
                languagePicker
                searchField
            }
        } content: {
            content
        }
        .onAppear {
            selectedLanguage = conversationTurnServices.toolService.languagePreference
        }
    }

    private var toolsCountText: String {
        String.localizedStringWithFormat(
            String(localized: "%lld tools available", table: "AgentAvailableToolsPlugin", comment: "Count of available tools"),
            Int64(tools.count)
        )
    }

    private var searchField: some View {
        AppSearchBar(
            text: $query,
            placeholder: LocalizedStringKey(String(localized: "Search tools", table: "AgentAvailableToolsPlugin"))
        )
        .frame(width: 280)
    }

    private var languagePicker: some View {
        Picker(String(localized: "Language", table: "AgentAvailableToolsPlugin"), selection: $selectedLanguage) {
            ForEach(LanguagePreference.allCases) { language in
                Text(language.displayName).tag(language)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 136)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if filteredTools.isEmpty {
                    emptyStateView
                } else {
                    toolRows
                }
            }
            .padding(.vertical, 6)
        }
        .appSurface(style: .subtle, cornerRadius: 8)
        .frame(minHeight: 340, maxHeight: 520)
    }

    private var emptyStateView: some View {
        AppEmptyState(
            icon: "wrench.and.screwdriver",
            title: "No tools found",
            description: "Try a different search keyword."
        )
    }

    private var toolRows: some View {
        ForEach(Array(filteredTools.enumerated()), id: \.offset) { _, tool in
            VStack(spacing: 0) {
                toolRow(tool)
                GlassDivider()
                    .padding(.leading, 18)
            }
        }
    }

    private func toolRow(_ tool: SuperAgentTool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(tool.name)
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .textSelection(.enabled)
                Spacer()
            }

            if !tool.description(for: selectedLanguage).isEmpty {
                Text(tool.description(for: selectedLanguage))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .textSelection(.enabled)
                    .lineLimit(3)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var filteredTools: [SuperAgentTool] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return tools.sorted { $0.name < $1.name } }
        return tools
            .filter {
                $0.name.localizedCaseInsensitiveContains(q)
                    || $0.description(for: selectedLanguage).localizedCaseInsensitiveContains(q)
            }
            .sorted { $0.name < $1.name }
    }
}
