import KitResume
import LumiUI
import SwiftUI

private typealias L = ResumeDesignerLocalization

/// Project-local resume document browser injected into the workspace Rail.
public struct ResumeRailView: View {
    @ObservedObject private var workspace: WorkspaceStore
    @LumiTheme private var theme

    init(workspace: WorkspaceStore) {
        self.workspace = workspace
    }

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
                    AppToolbarTitleLabel(title: L.string("Resumes"))
                    AppTag("\(workspace.projectResumes.count)", style: .subtle)
                    Spacer(minLength: 0)
                    AppIconButton(systemImage: "arrow.clockwise", action: workspace.reload)
                        .accessibilityLabel(L.string("Refresh"))
                        .help(L.string("Refresh"))
                }
            }
            .borderBottom()

            if workspace.projectStorageDirectory == nil {
                AppEmptyState(
                    icon: "folder",
                    title: L.string("Open a project to enable project-local storage.")
                )
            } else if workspace.projectResumes.isEmpty {
                AppEmptyState(
                    icon: "doc.badge.plus",
                    title: L.string("Ask the Agent to create a resume.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignTokens.Spacing.xs) {
                        ForEach(workspace.projectResumes) { document in
                            resumeRow(document)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                }
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func resumeRow(_ document: ResumeDocument) -> some View {
        AppListRow(
            isSelected: workspace.selectedResumeID == document.id,
            action: { workspace.select(resumeID: document.id) }
        ) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(theme.primary.opacity(0.10))
                    Image(systemName: "doc.text")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.primary)
                }
                .frame(width: 34, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(document.title)
                        .font(.appBodyEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text("\(document.paper.rawValue.uppercased()) · \(document.template.rawValue)")
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                workspace.deleteResume(id: document.id)
            } label: {
                Label(L.string("Delete"), systemImage: "trash")
            }
        }
    }
}

#Preview {
    ResumeRailView(workspace: WorkspaceStore.shared)
        .frame(width: 280, height: 500)
}
