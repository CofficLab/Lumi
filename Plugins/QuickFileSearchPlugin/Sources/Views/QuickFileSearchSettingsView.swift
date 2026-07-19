import LumiUI
import LumiKernel
import SwiftUI

/// 快速文件搜索设置视图
public struct QuickFileSearchSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    private let projectPath: String

    public init(projectPath: String) {
        self.projectPath = projectPath
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Quick File Search", bundle: .module),
            subtitle: LumiPluginLocalization.string("Fast file search with Cmd+P", bundle: .module),
            showHeader: false
        ) {
            statusCard
            instructionsCard
        }
    }

    private var statusCard: some View {
        AppCard {
            AppSettingsSection(
                title: LumiPluginLocalization.string("Current Status", bundle: .module),
                spacing: 12
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: projectPath.isEmpty ? "circle" : "checkmark.circle.fill")
                            .font(.appTitle)
                            .foregroundColor(projectPath.isEmpty ? theme.warning : theme.success)

                        VStack(alignment: .leading, spacing: 4) {
                            if projectPath.isEmpty {
                                Text(LumiPluginLocalization.string("No project selected", bundle: .module))
                                    .font(.appBody)
                                    .foregroundColor(theme.textPrimary)
                                Text(LumiPluginLocalization.string("Please select a project to enable file search", bundle: .module))
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                            } else {
                                Text(LumiPluginLocalization.string("Project indexed", bundle: .module))
                                    .font(.appBody)
                                    .foregroundColor(theme.textPrimary)
                                Text(URL(fileURLWithPath: projectPath).lastPathComponent)
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }

                        Spacer()
                    }
                }

                if !projectPath.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(theme.info)
                        Text(LumiPluginLocalization.string("File indexing is automatic when switching projects", bundle: .module))
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
    }

    private var instructionsCard: some View {
        AppCard {
            AppSettingsSection(
                title: LumiPluginLocalization.string("How to Use", bundle: .module),
                spacing: 8
            ) {
                instructionRow(key: "Cmd+P", description: LumiPluginLocalization.string("Open file search", bundle: .module))
                instructionRow(key: "↑ ↓", description: LumiPluginLocalization.string("Navigate results", bundle: .module))
                instructionRow(key: "Enter", description: LumiPluginLocalization.string("Select file", bundle: .module))
                instructionRow(key: "Esc", description: LumiPluginLocalization.string("Close search", bundle: .module))
            }
        }
    }

    private func instructionRow(key: String, description: String) -> some View {
        AppSettingsRow(verticalPadding: 6) {
            HStack(spacing: 12) {
                Text(key)
                    .font(.appBody)
                    .fontDesign(.monospaced)
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.appAccentSoftFill)
                    )

                Text(description)
                    .font(.appBody)
                    .foregroundColor(theme.textSecondary)

                Spacer()
            }
        }
    }
}

#Preview("Quick File Search Settings") {
    QuickFileSearchSettingsView(projectPath: "/tmp/MyProject")
        .inRootView()
        .frame(width: 600, height: 500)
}
