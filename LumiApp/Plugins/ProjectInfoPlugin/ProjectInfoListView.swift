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
                    .foregroundColor(.blue)
                Text("Project Info")
                    .font(.headline)
            }

            Divider()

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
                        .foregroundColor(.secondary)
                }
            }

            Divider()

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
                .foregroundColor(.secondary)
            Text(":")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
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
