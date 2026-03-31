import SwiftUI
import MagicKit

/// 快速文件搜索设置视图
struct QuickFileSearchSettingsView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @StateObject private var searchService = FileSearchService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 插件说明
            headerSection

            Divider()

            // 当前状态
            statusSection

            Divider()

            // 操作说明
            instructionsSection

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Quick File Search", systemImage: "magnifyingglass")
                .font(.title2.bold())

            Text("Fast file search with Cmd+P")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Status")
                .font(.headline)

            HStack {
                Image(systemName: projectVM.currentProjectPath.isEmpty ? "circle" : "checkmark.circle.fill")
                    .foregroundColor(projectVM.currentProjectPath.isEmpty ? .orange : .green)

                VStack(alignment: .leading, spacing: 4) {
                    if projectVM.currentProjectPath.isEmpty {
                        Text("No project selected")
                            .font(.body)
                        Text("Please select a project to enable file search")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Project indexed")
                            .font(.body)
                        Text("\(projectVM.currentProjectName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // 索引信息
            if !projectVM.currentProjectPath.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("File indexing is automatic when switching projects")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Use")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                instructionRow(
                    key: "Cmd+P",
                    description: "Open file search"
                )
                instructionRow(
                    key: "↑ ↓",
                    description: "Navigate results"
                )
                instructionRow(
                    key: "Enter",
                    description: "Select file"
                )
                instructionRow(
                    key: "Esc",
                    description: "Close search"
                )
            }
        }
    }

    private func instructionRow(key: String, description: String) -> some View {
        HStack(spacing: 12) {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(description)
                .font(.body)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Quick File Search Settings") {
    QuickFileSearchSettingsView()
        .inRootView()
        .frame(width: 600, height: 500)
}
