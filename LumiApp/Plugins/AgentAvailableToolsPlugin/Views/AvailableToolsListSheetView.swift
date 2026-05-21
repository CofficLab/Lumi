import SwiftUI

/// 可用工具列表详情视图（在 popover 中展示）
struct AvailableToolsListDetailView: View {
    @EnvironmentObject var conversationTurnServices: AppConversationTurnVM
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
        HStack(alignment: .center, spacing: 14) {
            headerTitle
            Spacer()
            languagePicker
            searchField
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Tools", table: "AgentAvailableToolsPlugin"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text(toolsCountText)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minWidth: 150, alignment: .leading)
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
        .background(Color.adaptive(light: "FFFFFF", dark: "14141A").opacity(0.82))
        .frame(minHeight: 340, maxHeight: 520)
    }

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "No tools found", table: "AgentAvailableToolsPlugin"))
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
            Text(String(localized: "Try a different search keyword.", table: "AgentAvailableToolsPlugin"))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }

    private var toolRows: some View {
        ForEach(Array(filteredTools.enumerated()), id: \.offset) { _, tool in
            VStack(spacing: 0) {
                toolRow(tool)
                Divider()
                    .padding(.leading, 18)
            }
        }
    }

    private func toolRow(_ tool: SuperAgentTool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(tool.name)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    .textSelection(.enabled)
                Spacer()
            }

            if !tool.description(for: selectedLanguage).isEmpty {
                Text(tool.description(for: selectedLanguage))
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
