import SwiftUI
import ToolKit
import LumiUI

/// 可用工具列表详情视图（在 popover 中展示）
struct AvailableToolsListDetailView: View {
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
}

// MARK: - View

extension AvailableToolsListDetailView {
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
}

// MARK: - Computed

extension AvailableToolsListDetailView {
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

// MARK: - Preview

#Preview {
    AvailableToolsListDetailView()
        .frame(width: 632, height: 600)
        .inRootView()
}
