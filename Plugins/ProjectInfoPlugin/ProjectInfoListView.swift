import SwiftUI

/// 项目信息列表视图
struct ProjectInfoListView: View {
    let tab: String
    let project: Project?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: ProjectInfoPlugin.iconName)
                    .foregroundColor(.blue)
                Text("项目信息")
                    .font(.headline)
            }

            Divider()

            // 标签页信息
            VStack(alignment: .leading, spacing: 8) {
                Text("标签页信息")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ProjectInfoRow(title: "当前标签页", value: tab)
            }

            // 项目信息
            VStack(alignment: .leading, spacing: 8) {
                Text("项目信息")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let project = project {
                    ProjectInfoRow(title: "项目名称", value: project.name)
                    ProjectInfoRow(title: "项目ID", value: project.id)
                    ProjectInfoRow(title: "状态", value: "活跃")
                } else {
                    Text("未选择项目")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // 统计信息
            VStack(alignment: .leading, spacing: 8) {
                Text("统计信息")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ProjectInfoRow(title: "总标签页数", value: "1")
                ProjectInfoRow(title: "总项目数", value: project != nil ? "1" : "0")
            }
        }
        .padding()
    }
}

/// 信息行视图（私有辅助组件）
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
        project: Project(id: "123", name: "示例项目")
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
