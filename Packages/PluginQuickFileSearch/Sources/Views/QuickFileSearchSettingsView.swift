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
            title: LumiPluginLocalization.string("Current Status", bundle: .module),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: projectPath.isEmpty
                        ? LumiPluginLocalization.string("No project selected", bundle: .module)
                        : LumiPluginLocalization.string("Project indexed", bundle: .module),
                    description: projectPath.isEmpty
                        ? LumiPluginLocalization.string("Please select a project to enable file search", bundle: .module)
                        : URL(fileURLWithPath: projectPath).lastPathComponent,
                    icon: projectPath.isEmpty ? "circle" : "checkmark.circle.fill"
                ) {
                    EmptyView()
                }

                if !projectPath.isEmpty {
                    Divider()
                        .padding(.vertical, 8)

                    AppSettingRow(
                        title: LumiPluginLocalization.string("File indexing is automatic when switching projects", bundle: .module),
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
            title: LumiPluginLocalization.string("How to Use", bundle: .module),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                instructionRow(
                    key: "Cmd+P",
                    description: LumiPluginLocalization.string("Open file search", bundle: .module),
                    icon: "command"
                )
                Divider().padding(.vertical, 8)
                instructionRow(
                    key: "↑ ↓",
                    description: LumiPluginLocalization.string("Navigate results", bundle: .module),
                    icon: "arrow.up.arrow.down"
                )
                Divider().padding(.vertical, 8)
                instructionRow(
                    key: "Enter",
                    description: LumiPluginLocalization.string("Select file", bundle: .module),
                    icon: "return"
                )
                Divider().padding(.vertical, 8)
                instructionRow(
                    key: "Esc",
                    description: LumiPluginLocalization.string("Close search", bundle: .module),
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
