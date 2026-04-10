import SwiftUI

/// 中间栏视图：Agent 模式显示插件提供的 detail 视图，App 模式为空
struct MiddleColumn: View {
    @EnvironmentObject var app: GlobalVM
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var layoutVM: LayoutVM

    var body: some View {
        Group {
            if app.selectedMode == .agent {
                agentDetailContent
            } else {
                appModeContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var agentDetailContent: some View {
        let entries = pluginProvider.getAgentDetailEntries()
        if entries.isEmpty {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                if entries.count > 1 {
                    detailSwitcher(entries: entries)
                    GlassDivider()
                }

                currentEntry(in: entries).view
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minWidth: 200, idealWidth: 300)
            .onAppear {
                ensureValidSelection(entries: entries)
            }
            .onChange(of: entries) { _, newEntries in
                ensureValidSelection(entries: newEntries)
            }
        }
    }

    @ViewBuilder
    private var appModeContent: some View {
        if app.hasCurrentNavigationContent(pluginVM: pluginProvider) {
            app.getCurrentNavigationView(pluginVM: pluginProvider)
        } else {
            NavigationEmptyGuideView()
        }
    }

    private func ensureValidSelection(entries: [PluginVM.AgentDetailEntry]) {
        let availableIds = entries.map { $0.id }
        layoutVM.restoreSelectedDetail(from: availableIds)
    }

    private func currentEntry(in entries: [PluginVM.AgentDetailEntry]) -> PluginVM.AgentDetailEntry {
        if let selected = entries.first(where: { $0.id == layoutVM.selectedAgentDetailId }) {
            return selected
        }
        return entries[0]
    }

    private func detailSwitcher(entries: [PluginVM.AgentDetailEntry]) -> some View {
        HStack(spacing: AppUI.Spacing.sm) {
            ForEach(entries) { entry in
                Button(action: {
                    layoutVM.selectAgentDetail(entry.id)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: entry.icon)
                        Text(entry.title)
                            .lineLimit(1)
                    }
                    .font(AppUI.Typography.caption1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundColor(layoutVM.selectedAgentDetailId == entry.id ? .white : AppUI.Color.semantic.textPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: AppUI.Radius.sm, style: .continuous)
                            .fill(layoutVM.selectedAgentDetailId == entry.id ? Color.accentColor : Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppUI.Spacing.md)
        .padding(.vertical, AppUI.Spacing.sm)
    }
}
