import os
import AgentToolKit
import LumiUI
import SuperLogKit
import SwiftUI
import LumiCoreKit

/// 可用工具插件
///
/// 在状态栏右侧提供可用工具按钮（AvailableToolsButton）。
public actor AgentAvailableToolsPlugin: SuperPlugin, SuperLog {
    public nonisolated static let emoji = "🧰"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-available-tools")

    public static let id = "AgentAvailableToolsPlugin"
    public static let displayName = String(localized: "Tools", bundle: .module)
    public static let description = String(localized: "Show all available tools", bundle: .module)
    public static let iconName = "wrench.and.screwdriver"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 85 }
    public static let policy: PluginPolicy = .optOut

    /// 默认启用，用户可在设置中关闭。

    public static let shared = AgentAvailableToolsPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - StatusBar Views

    /// 状态栏右侧：可用工具按钮（仅在编辑器激活时显示）
    @MainActor
    public func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        return AnyView(AvailableToolsButton(context: context))
    }
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
            title: String(localized: "Tools", bundle: .module),
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
            String(localized: "%lld tools available", bundle: .module, comment: "Count of available tools"),
            Int64(tools.count)
        )
    }

    private var searchField: some View {
        AppSearchBar(
            text: $query,
            placeholder: LocalizedStringKey(String(localized: "Search tools", bundle: .module))
        )
        .frame(width: 280)
    }

    private var languagePicker: some View {
        Picker(String(localized: "Language", bundle: .module), selection: $selectedLanguage) {
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
            title: String(localized: "No tools found", bundle: .module),
            description: String(localized: "Try a different search keyword.", bundle: .module)
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
