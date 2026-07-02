import os
import AgentToolKit
import LumiUI
import SwiftUI
import LumiCoreKit

/// 可用工具插件
///
/// 在状态栏右侧提供可用工具按钮（AvailableToolsButton）。
public enum ToolAvailablePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "wrench.and.screwdriver"

    public static let info = LumiPluginInfo(
        id: "ToolAvailable",
        displayName: LumiPluginLocalization.string("Tools", bundle: .module),
        description: LumiPluginLocalization.string("Show all available tools", bundle: .module),
        order: 85
    )
}

private struct AvailableToolsButton: View {
    let context: PluginContext

    var body: some View {
        StatusBarHoverContainer(
            detailView: AvailableToolsListDetailView(context: context),
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
    @LumiTheme private var theme: any LumiUITheme

    let context: PluginContext
    @State private var query = ""
    @State private var selectedLanguage: LanguagePreference

    init(context: PluginContext) {
        self.context = context
        self._selectedLanguage = State(initialValue: context.toolLanguagePreference)
    }

    private var tools: [SuperAgentTool] {
        context.availableTools
    }

    var body: some View {
        StatusBarPopoverScaffold(
            title: LumiPluginLocalization.string("Tools", bundle: .module),
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
    }

    private var toolsCountText: String {
        String.localizedStringWithFormat(
            LumiPluginLocalization.string("%lld tools available", bundle: .module),
            Int64(tools.count)
        )
    }

    private var searchField: some View {
        AppSearchBar(
            text: $query,
            placeholder: LocalizedStringKey(LumiPluginLocalization.string("Search tools", bundle: .module))
        )
        .frame(width: 280)
    }

    private var languagePicker: some View {
        Picker(LumiPluginLocalization.string("Language", bundle: .module), selection: $selectedLanguage) {
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
            title: LumiPluginLocalization.string("No tools found", bundle: .module),
            description: LumiPluginLocalization.string("Try a different search keyword.", bundle: .module)
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
