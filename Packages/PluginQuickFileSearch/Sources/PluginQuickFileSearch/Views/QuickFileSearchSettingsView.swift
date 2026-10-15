import LumiUI
import SwiftUI

/// 快速文件搜索设置视图
public struct QuickFileSearchSettingsView: View {
    private let projectPath: String

    public init(projectPath: String) {
        self.projectPath = projectPath
    }

    public var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                statusSection
                instructionsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusSection: some View {
        AppSettingSection(
            title: pluginLocalization.string("Current Status"),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: projectPath.isEmpty
                        ? pluginLocalization.string("No project selected")
                        : pluginLocalization.string("Project indexed"),
                    description: projectPath.isEmpty
                        ? pluginLocalization.string("Please select a project to enable file search")
                        : URL(fileURLWithPath: projectPath).lastPathComponent,
                    icon: projectPath.isEmpty ? "circle" : "checkmark.circle.fill"
                ) {
                    EmptyView()
                }

                if !projectPath.isEmpty {
                    Divider()
                        .padding(.vertical, 8)

                    AppSettingRow(
                        title: pluginLocalization.string("File indexing is automatic when switching projects"),
                        icon: "info.circle"
                    ) {
                        EmptyView()
                    }
                }
            }
        }
    }

    private var instructionsSection: some View {
        AppSettingSection(
            title: pluginLocalization.string("How to Use"),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                instructionRow(
                    key: "Cmd+P",
                    description: pluginLocalization.string("Open file search"),
                    icon: "command"
                )
                Divider().padding(.vertical, 8)
                instructionRow(
                    key: "↑ ↓",
                    description: pluginLocalization.string("Navigate results"),
                    icon: "arrow.up.arrow.down"
                )
                Divider().padding(.vertical, 8)
                instructionRow(
                    key: "Enter",
                    description: pluginLocalization.string("Select file"),
                    icon: "return"
                )
                Divider().padding(.vertical, 8)
                instructionRow(
                    key: "Esc",
                    description: pluginLocalization.string("Close search"),
                    icon: "escape"
                )
            }
        }
    }

    private func instructionRow(key: String, description: String, icon: String) -> some View {
        AppSettingRow(title: description, icon: icon) {
            AppTag(key, style: .subtle)
        }
    }
}

#Preview("Quick File Search Settings") {
    QuickFileSearchSettingsView(projectPath: "/tmp/MyProject")
        .inRootView()
        .frame(width: 600, height: 500)
}
