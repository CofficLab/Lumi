import KitAppStorePromo
import LumiUI
import SwiftUI

/// Promo 任务 Rail 容器：列出当前项目下的任务与图像。
public struct PromoRailView: View {
    @ObservedObject private var workspace: WorkspaceStore
    @LumiTheme private var theme
    @State private var expandedTaskIDs: Set<String> = []
    @State private var isProjectExpanded = true

    // MARK: - 初始化

    init(workspace: WorkspaceStore) {
        self.workspace = workspace
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(PromoLocalization.string("Promo Tasks")).font(.headline)
                Spacer()
                Text("\(totalTaskCount)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(theme.textTertiary)
                Button { workspace.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textTertiary)
                    .help(PromoLocalization.string("Refresh"))
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            Divider()

            if workspace.projectStorageDirectory == nil {
                PromoRailEmptyView(message: PromoLocalization.string("Plugin storage is unavailable."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        projectSection
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            if let selectedTaskID = workspace.selectedTaskID {
                expandedTaskIDs.insert(selectedTaskID)
            }
        }
        .onChange(of: workspace.selectedTaskID) { _, taskID in
            if let taskID { expandedTaskIDs.insert(taskID) }
        }
    }

    // MARK: - 子视图

    @ViewBuilder
    private var projectSection: some View {
        let tasks = workspace.projectTasks
        let isUnavailable = workspace.currentProjectPath == nil
        let subtitle = workspace.currentProjectPath.map { "· \(URL(fileURLWithPath: $0).lastPathComponent)" } ?? ""
        PromoScopeSectionView(
            isExpanded: $isProjectExpanded,
            icon: "folder",
            iconColor: theme.primary,
            title: PromoLocalization.string("In Project"),
            subtitle: subtitle,
            count: tasks.count,
            isUnavailable: isUnavailable,
            unavailableMessage: PromoLocalization.string("Open a project to enable project-local storage."),
            emptyMessage: PromoLocalization.string("Ask the Agent to create a promotional artwork task.")
        ) {
            if tasks.isEmpty {
                PromoScopeEmptyView(
                    message: PromoLocalization.string("Ask the Agent to create a promotional artwork task.")
                )
            } else {
                ForEach(tasks) { task in
                    PromoTaskTreeView(
                        workspace: workspace,
                        isExpanded: expansionBinding(for: task.id),
                        task: task
                    )
                }
            }
        }
    }

    // MARK: - 计算属性

    private var totalTaskCount: Int {
        workspace.projectTasks.count
    }

    private func expansionBinding(for taskID: String) -> Binding<Bool> {
        Binding(
            get: { expandedTaskIDs.contains(taskID) },
            set: { isExpanded in
                if isExpanded { expandedTaskIDs.insert(taskID) }
                else { expandedTaskIDs.remove(taskID) }
            }
        )
    }
}

// MARK: - 预览

#Preview {
    PromoRailView(workspace: WorkspaceStore.shared)
        .frame(width: 280, height: 500)
}
