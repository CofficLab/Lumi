import AppStorePromoKit
import LumiUI
import SwiftUI

/// Promo 任务 Rail 容器：列出 project / app 两个 scope 下的任务与图像。
public struct PromoRailView: View {
    @ObservedObject private var workspace = WorkspaceStore.shared
    @LumiTheme private var theme
    @State private var expandedTaskIDs: Set<String> = []
    @State private var expandedScopes: Set<Scope> = [.project, .app]

    // MARK: - 初始化

    public init() {}

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

            if workspace.appStorageDirectory == nil {
                PromoRailEmptyView(message: PromoLocalization.string("Plugin storage is unavailable."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        scopeSection(.project)
                        scopeSection(.app)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            workspace.reload()
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
    private func scopeSection(_ scope: Scope) -> some View {
        let tasks = workspace.tasks(for: scope)
        let isUnavailable = (scope == .project && workspace.currentProjectPath == nil)
        let title = scope == .project
            ? PromoLocalization.string("In Project")
            : PromoLocalization.string("In App")
        let subtitle: String = {
            if scope == .project, let path = workspace.currentProjectPath {
                let name = URL(fileURLWithPath: path).lastPathComponent
                return "· \(name)"
            }
            return ""
        }()
        PromoScopeSectionView(
            isExpanded: scopeBinding(scope),
            icon: scope == .project ? "folder" : "app.badge",
            iconColor: scope == .project ? theme.primary : theme.textTertiary,
            title: title,
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
                        scope: scope,
                        task: task
                    )
                }
            }
        }
    }

    // MARK: - 计算属性

    private var totalTaskCount: Int {
        workspace.projectTasks.count + workspace.appTasks.count
    }

    // MARK: - 私有方法

    private func scopeBinding(_ scope: Scope) -> Binding<Bool> {
        Binding(
            get: { expandedScopes.contains(scope) },
            set: { isExpanded in
                if isExpanded { expandedScopes.insert(scope) }
                else { expandedScopes.remove(scope) }
            }
        )
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
    PromoRailView()
        .frame(width: 280, height: 500)
}