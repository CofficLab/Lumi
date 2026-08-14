import LumiUI
import ResumeKit
import SwiftUI

/// 简历 Rail 容器：列出 project / app 两个 scope 下的简历。
public struct ResumeRailView: View {
    @ObservedObject private var workspace = WorkspaceStore.shared
    @LumiTheme private var theme
    @State private var expandedScopes: Set<Scope> = [.project, .app]

    // MARK: - 初始化

    public init() {}

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(ResumeLocalization.string("Resumes")).font(.headline)
                Spacer()
                Text("\(totalResumeCount)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(theme.textTertiary)
                Button { workspace.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textTertiary)
                    .help(ResumeLocalization.string("Refresh"))
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            Divider()

            if workspace.appStorageDirectory == nil {
                ResumeEmptyStateView(message: ResumeLocalization.string("Plugin storage is unavailable."))
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
        .onAppear { workspace.reload() }
    }

    // MARK: - 子视图

    @ViewBuilder
    private func scopeSection(_ scope: Scope) -> some View {
        let resumes = workspace.resumes(for: scope)
        let isUnavailable = (scope == .project && workspace.currentProjectPath == nil)
        DisclosureGroup(isExpanded: scopeBinding(scope)) {
            if resumes.isEmpty {
                Text(isUnavailable
                     ? ResumeLocalization.string("Open a project to enable project-local storage.")
                     : ResumeLocalization.string("Ask the Agent to create a resume."))
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
                    .padding(.leading, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.xs)
            } else {
                ForEach(resumes) { document in
                    resumeRow(document, scope: scope)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: scope == .project ? "folder" : "app.badge")
                    .font(.caption)
                    .foregroundStyle(scope == .project ? theme.primary : theme.textTertiary)
                Text(scope.displayName()).font(.subheadline.weight(.medium))
                if scope == .project, let path = workspace.currentProjectPath {
                    Text("· \(URL(fileURLWithPath: path).lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                Text("\(resumes.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.textTertiary)
            }
            .contentShape(Rectangle())
        }
    }

    private func resumeRow(_ document: ResumeDocument, scope: Scope) -> some View {
        let isSelected = workspace.selectedScope == scope && workspace.selectedResumeID == document.id
        return Button {
            workspace.selectScope(scope, resumeID: document.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundStyle(isSelected ? theme.primary : theme.textTertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(document.title)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? theme.primary : theme.textPrimary)
                    Text("\(document.paper.rawValue.uppercased()) · \(document.template.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.vertical, 2)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? theme.primary.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                workspace.deleteResume(scope: scope, id: document.id)
            } label: {
                Label(ResumeLocalization.string("Delete"), systemImage: "trash")
            }
        }
    }

    // MARK: - 计算属性

    private var totalResumeCount: Int {
        workspace.projectResumes.count + workspace.appResumes.count
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
}

// MARK: - 预览

#Preview {
    ResumeRailView()
        .frame(width: 280, height: 500)
}
