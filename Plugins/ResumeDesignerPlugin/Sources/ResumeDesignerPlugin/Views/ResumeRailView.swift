import LumiUI
import ResumeKit
import SwiftUI

/// 简历 Rail 容器：列出应用数据目录（app 存储）下的简历。
public struct ResumeRailView: View {
    @ObservedObject private var workspace = WorkspaceStore.shared
    @LumiTheme private var theme

    // MARK: - 初始化

    public init() {}

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(ResumeLocalization.string("Resumes")).font(.headline)
                Spacer()
                Text("\(workspace.appResumes.count)")
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
            } else if workspace.appResumes.isEmpty {
                ResumeEmptyStateView(message: ResumeLocalization.string("Ask the Agent to create a resume."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        ForEach(workspace.appResumes) { document in
                            resumeRow(document)
                        }
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

    private func resumeRow(_ document: ResumeDocument) -> some View {
        let isSelected = workspace.selectedResumeID == document.id
        return Button {
            workspace.select(resumeID: document.id)
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
                workspace.deleteResume(id: document.id)
            } label: {
                Label(ResumeLocalization.string("Delete"), systemImage: "trash")
            }
        }
    }
}

// MARK: - 预览

#Preview {
    ResumeRailView()
        .frame(width: 280, height: 500)
}
