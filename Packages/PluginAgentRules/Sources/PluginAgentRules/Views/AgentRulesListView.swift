import LumiUI
import SwiftUI

/// Chat Toolbar 弹出的规则列表：复刻 PluginSkill 的 LumiUI 样式。
struct AgentRulesListView: View {
    let rules: [AgentRuleMetadata]
    @Binding var selectedRule: AgentRule?

    @State private var searchText = ""

    private var filteredRules: [AgentRuleMetadata] {
        if searchText.isEmpty {
            return rules
        }
        return rules.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
            || $0.id.localizedCaseInsensitiveContains(searchText)
            || $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if selectedRule != nil {
                ruleDetailView
            } else {
                listView
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if selectedRule != nil {
                Button {
                    selectedRule = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
            }

            AppSearchBar(
                text: $searchText,
                placeholder: LocalizedStringKey(LumiPluginLocalization.string("Search", bundle: .module))
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var listView: some View {
        if filteredRules.isEmpty {
            if rules.isEmpty {
                AppEmptyState(
                    icon: "doc.text",
                    title: LumiPluginLocalization.string("No Rules", bundle: .module),
                    description: LumiPluginLocalization.string("No rules available for the current project.", bundle: .module)
                )
                .frame(maxWidth: .infinity, minHeight: 126)
            } else {
                AppEmptyState(
                    icon: "magnifyingglass",
                    title: LumiPluginLocalization.string("No Rules", bundle: .module)
                )
                .frame(maxWidth: .infinity, minHeight: 126)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredRules) { rule in
                        AgentRuleRowView(rule: rule) {
                            Task {
                                await loadRuleDetail(rule)
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 400)
        }
    }

    @ViewBuilder
    private var ruleDetailView: some View {
        if let rule = selectedRule {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(rule.title)
                        .font(.headline)

                    if !rule.description.isEmpty {
                        Text(rule.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    Text(rule.content)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
        }
    }

    private func loadRuleDetail(_ rule: AgentRuleMetadata) async {
        guard let path = AgentRulesRuntime.project?.currentProject?.path else { return }
        do {
            selectedRule = try await AgentRulesService.shared.readRule(projectPath: path, filename: rule.filename)
        } catch {
            // 忽略错误
        }
    }
}
