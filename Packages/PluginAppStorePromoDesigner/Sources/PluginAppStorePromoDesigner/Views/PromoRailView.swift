import KitAppStorePromo
import LumiUI
import SwiftUI

/// Promo 任务 Rail 容器：列出当前项目下的任务与图像。
public struct PromoRailView: View {
    @ObservedObject private var workspace: WorkspaceStore
    @LumiTheme private var theme
    @State private var expandedTaskIDs: Set<String> = []

    // MARK: - 初始化

    init(workspace: WorkspaceStore) {
        self.workspace = workspace
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            AppToolbarContainer(
                height: 40,
                backgroundStyle: .panel,
                padding: EdgeInsets(
                    top: DesignTokens.Spacing.sm,
                    leading: DesignTokens.Spacing.md,
                    bottom: DesignTokens.Spacing.sm,
                    trailing: DesignTokens.Spacing.md
                )
            ) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(PromoLocalization.string("Promo Tasks"))
                        .font(.appSectionTitle)
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: 0)
                    Text("\(totalTaskCount)")
                        .font(.appMonoMicro)
                        .foregroundStyle(theme.textTertiary)
                    AppIconButton(
                        systemImage: "arrow.clockwise",
                        action: workspace.reload
                    )
                    .accessibilityLabel(PromoLocalization.string("Refresh"))
                    .help(PromoLocalization.string("Refresh"))
                }
            }
            .borderBottom()

            if workspace.projectStorageDirectory == nil {
                AppEmptyState(
                    icon: "rectangle.stack.badge.plus",
                    title: PromoLocalization.string("Plugin storage is unavailable.")
                )
            } else if workspace.projectTasks.isEmpty {
                AppEmptyState(
                    icon: "rectangle.stack.badge.plus",
                    title: PromoLocalization.string("Ask the Agent to create a promotional artwork task.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        ForEach(workspace.projectTasks) { task in
                            PromoTaskTreeView(
                                workspace: workspace,
                                isExpanded: expansionBinding(for: task.id),
                                task: task
                            )
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
        .onAppear {
            if let selectedTaskID = workspace.selectedTaskID {
                expandedTaskIDs.insert(selectedTaskID)
            }
        }
        .onChange(of: workspace.selectedTaskID) { _, taskID in
            if let taskID { expandedTaskIDs.insert(taskID) }
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
