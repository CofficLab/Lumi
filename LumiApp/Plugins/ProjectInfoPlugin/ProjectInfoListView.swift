import SwiftUI

/// Project info list view
struct ProjectInfoListView: View {
    let tab: String
    let project: Project?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            HStack {
                Image(systemName: ProjectInfoPlugin.iconName)
                    .foregroundColor(DesignTokens.Color.semantic.info)
                Text("Project Info")
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            }

            GlassDivider()

            // Tab Information
            VStack(alignment: .leading, spacing: 8) {
                Text("Tab Information")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ProjectInfoRow(title: "Current Tab", value: tab)
            }

            // Project Information
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Information")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let project = project {
                    ProjectInfoRow(title: "Project Name", value: project.name)
                    ProjectInfoRow(title: "Project ID", value: project.id)
                    ProjectInfoRow(title: "Status", value: "Active")
                } else {
                    Text("No project selected")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }

            GlassDivider()

            // Statistics
            VStack(alignment: .leading, spacing: 8) {
                Text("Statistics")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ProjectInfoRow(title: "Total Tabs", value: "1")
                ProjectInfoRow(title: "Total Projects", value: project != nil ? "1" : "0")
            }
        }
        .padding()
    }
}

/// Information row view (Private helper component)
private struct ProjectInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            Text(":")
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            Text(value)
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("With Project") {
    ProjectInfoListView(
        tab: "main",
        project: Project(id: "123", name: "Example Project")
    )
    .frame(width: 400, height: 400)
}

#Preview("Without Project") {
    ProjectInfoListView(
        tab: "main",
        project: nil
    )
    .frame(width: 400, height: 400)
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800)
        .frame(height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200)
        .frame(height: 1200)
}
