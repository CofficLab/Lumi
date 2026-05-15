import SwiftUI

/// 可用工具列表详情视图（在 popover 中展示）
struct AvailableToolsListDetailView: View {
    @EnvironmentObject var conversationTurnServices: ConversationTurnServices
    @State private var query = ""
    @State private var selectedLanguage: LanguagePreference = .english

    private var tools: [SuperAgentTool] {
        conversationTurnServices.toolService.allTools
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onAppear {
            selectedLanguage = conversationTurnServices.toolService.languagePreference
        }
    }
}

// MARK: - View

extension AvailableToolsListDetailView {
    private var header: some View {
        HStack(spacing: 12) {
            headerTitle
            Spacer()
            languagePicker
            searchField
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Tools", table: "AgentAvailableToolsPlugin"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

            Text(toolsCountText)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
    }

    private var toolsCountText: String {
        String.localizedStringWithFormat(
            String(localized: "%lld tools available", table: "AgentAvailableToolsPlugin", comment: "Count of available tools"),
            Int64(tools.count)
        )
    }

    private var searchField: some View {
        TextField(String(localized: "Search tools", table: "AgentAvailableToolsPlugin"), text: $query)
            .textFieldStyle(.roundedBorder)
            .frame(width: 200)
    }

    private var languagePicker: some View {
        Picker(String(localized: "Language", table: "AgentAvailableToolsPlugin"), selection: $selectedLanguage) {
            ForEach(LanguagePreference.allCases) { language in
                Text(language.displayName).tag(language)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 128)
    }

    private var content: some View {
        List {
            if filteredTools.isEmpty {
                emptyStateView
            } else {
                toolRows
            }
        }
        .listStyle(.inset)
        .frame(minHeight: 300, maxHeight: 480)
    }

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "No tools found", table: "AgentAvailableToolsPlugin"))
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
            Text(String(localized: "Try a different search keyword.", table: "AgentAvailableToolsPlugin"))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.vertical, 10)
    }

    private var toolRows: some View {
        ForEach(Array(filteredTools.enumerated()), id: \.offset) { _, tool in
            toolRow(tool)
        }
    }

    private func toolRow(_ tool: SuperAgentTool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(tool.name)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    .textSelection(.enabled)
                Spacer()
            }

            if !tool.description(for: selectedLanguage).isEmpty {
                Text(tool.description(for: selectedLanguage))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .textSelection(.enabled)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 6)
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
        .frame(width: 480, height: 520)
        .inRootView()
}
