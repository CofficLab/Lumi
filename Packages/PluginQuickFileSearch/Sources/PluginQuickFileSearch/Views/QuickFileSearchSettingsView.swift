import LumiUI
import SwiftUI

/// 快速文件搜索设置视图
public struct QuickFileSearchSettingsView: View {
    @LumiTheme private var theme

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
        .environment(\.appSettingsCardStyleOverride, .subtle)
    }

    private var statusSection: some View {
        AppCard {
            AppSettingsSection(
                title: pluginLocalization.string("Current Status")
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: projectPath.isEmpty ? "circle" : "checkmark.circle.fill")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                projectPath.isEmpty
                                    ? pluginLocalization.string("No project selected")
                                    : pluginLocalization.string("Project indexed")
                            )
                            .font(.appBody)
                            .foregroundColor(theme.textPrimary)
                            Text(
                                projectPath.isEmpty
                                    ? pluginLocalization.string("Please select a project to enable file search")
                                    : URL(fileURLWithPath: projectPath).lastPathComponent
                            )
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        EmptyView()
                    }
                }

                if !projectPath.isEmpty {
                    AppSettingsRow {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .font(.appCallout)
                                .foregroundColor(theme.primary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(pluginLocalization.string("File indexing is automatic when switching projects"))
                                    .font(.appBody)
                                    .foregroundColor(theme.textPrimary)
                            }

                            Spacer()

                            EmptyView()
                        }
                    }
                }
            }
        }
    }

    private var instructionsSection: some View {
        AppCard {
            AppSettingsSection(
                title: pluginLocalization.string("How to Use")
            ) {
                instructionRow(
                    key: "Cmd+P",
                    description: pluginLocalization.string("Open file search"),
                    icon: "command"
                )
                instructionRow(
                    key: "↑ ↓",
                    description: pluginLocalization.string("Navigate results"),
                    icon: "arrow.up.arrow.down"
                )
                instructionRow(
                    key: "Enter",
                    description: pluginLocalization.string("Select file"),
                    icon: "return"
                )
                instructionRow(
                    key: "Esc",
                    description: pluginLocalization.string("Close search"),
                    icon: "escape"
                )
            }
        }
    }

    private func instructionRow(key: String, description: String, icon: String) -> some View {
        AppSettingsRow {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.appCallout)
                    .foregroundColor(theme.primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(description)
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                }

                Spacer()

                AppTag(key, style: .subtle)
            }
        }
    }
}

#Preview("Quick File Search Settings") {
    QuickFileSearchSettingsView(projectPath: "/tmp/MyProject")
        .inRootView()
        .frame(width: 600, height: 500)
}
