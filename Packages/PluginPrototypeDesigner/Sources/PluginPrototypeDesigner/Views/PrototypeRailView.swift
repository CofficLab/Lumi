import KitHTMLPreview
import LumiUI
import SwiftUI

/// 原型设计器 Rail 容器：列出当前项目下的原型项目与屏幕。
public struct PrototypeRailView: View {
    @ObservedObject private var workspace: WorkspaceStore
    @LumiTheme private var theme
    @State private var expandedProjectIDs: Set<String> = []

    // MARK: - 初始化

    init(workspace: WorkspaceStore) {
        self.workspace = workspace
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            AppToolbarContainer {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(PrototypeLocalization.string("Prototypes"))
                        .font(.appSectionTitle)
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: 0)
                    // 计数是数据而非文案。
                    Text(verbatim: "\(workspace.projects.count)")
                        .font(.appMonoMicro)
                        .foregroundStyle(theme.textTertiary)
                    AppIconButton(systemImage: "arrow.clockwise", action: workspace.reload)
                        .accessibilityLabel(PrototypeLocalization.string("Refresh"))
                        .help(PrototypeLocalization.string("Refresh"))
                }
            }
            .borderBottom()

            if workspace.projectStorageDirectory == nil {
                AppEmptyState(
                    icon: "rectangle.on.rectangle.angled",
                    title: PrototypeLocalization.string("Open a project to enable project-local storage.")
                )
            } else if workspace.projects.isEmpty {
                AppEmptyState(
                    icon: "rectangle.on.rectangle.angled",
                    title: PrototypeLocalization.string("Ask the Agent to create a prototype.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        ForEach(workspace.projects) { project in
                            PrototypeTreeView(
                                workspace: workspace,
                                isExpanded: expansionBinding(for: project.id),
                                project: project
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
            if let selectedProjectID = workspace.selectedProjectID {
                expandedProjectIDs.insert(selectedProjectID)
            }
        }
        .onChange(of: workspace.selectedProjectID) { _, projectID in
            if let projectID { expandedProjectIDs.insert(projectID) }
        }
    }

    // MARK: - 私有方法

    private func expansionBinding(for projectID: String) -> Binding<Bool> {
        Binding(
            get: { expandedProjectIDs.contains(projectID) },
            set: { isExpanded in
                if isExpanded { expandedProjectIDs.insert(projectID) }
                else { expandedProjectIDs.remove(projectID) }
            }
        )
    }
}

// MARK: - 预览

#Preview {
    PrototypeRailView(workspace: WorkspaceStore.shared)
        .frame(width: 280, height: 500)
}
