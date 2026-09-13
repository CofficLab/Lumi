import LumiUI
import ProviderProject
import SwiftUI

/// Chat 工具栏规则入口：显示可用规则数量，点击弹出列表。
///
/// 样式与 ``SkillChatToolbarView`` 保持一致。
struct AgentRulesChatToolbarView: View {
    @LumiTheme private var theme: any LumiUITheme

    let project: (any ProjectProviding)?

    @State private var isPopoverPresented = false
    @State private var rules: [AgentRuleMetadata] = []
    @State private var selectedRule: AgentRule?

    private var rulesService: AgentRulesService {
        AgentRulesService.shared
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10, weight: .medium))

                if !rules.isEmpty {
                    Text("\(rules.count)")
                        .font(.system(size: 10, weight: .medium))
                        .contentTransition(.numericText())
                } else {
                    Text(LumiPluginLocalization.string("Rules", bundle: .module))
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundColor(Color.accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Color.accentColor.opacity(0.22),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(Text(rules.isEmpty ? "无可用规则" : "\(rules.count) 个可用规则"))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            AgentRulesListView(rules: rules, selectedRule: $selectedRule)
                .frame(width: 360)
                .frame(minHeight: 220, maxHeight: 480)
        }
        .task {
            await refresh()
        }
        .onChange(of: project?.currentProject?.path) { _, _ in
            Task { @MainActor in
                await refresh()
            }
        }
    }

    private func refresh() async {
        guard let path = project?.currentProject?.path else {
            rules = []
            return
        }
        do {
            rules = try await rulesService.listRules(projectPath: path)
        } catch {
            rules = []
        }
    }
}
