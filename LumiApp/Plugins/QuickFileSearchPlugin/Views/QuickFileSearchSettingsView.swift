import LumiUI
import SwiftUI

/// 快速文件搜索设置视图
struct QuickFileSearchSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
        PluginSettingsScaffold(
            String(localized: "Quick File Search", table: "QuickFileSearch"),
            subtitle: String(localized: "Fast file search with Cmd+P", table: "QuickFileSearch")
        ) {
            statusCard
            instructionsCard
        }
    }

    private var statusCard: some View {
        AppCard {
            AppSettingsSection(
                title: String(localized: "Current Status", table: "QuickFileSearch"),
                spacing: 12
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: projectVM.currentProjectPath.isEmpty ? "circle" : "checkmark.circle.fill")
                            .font(.appTitle)
                            .foregroundColor(projectVM.currentProjectPath.isEmpty ? theme.warning : theme.success)

                        VStack(alignment: .leading, spacing: 4) {
                            if projectVM.currentProjectPath.isEmpty {
                                Text(String(localized: "No project selected", table: "QuickFileSearch"))
                                    .font(.appBody)
                                    .foregroundColor(theme.textPrimary)
                                Text(String(localized: "Please select a project to enable file search", table: "QuickFileSearch"))
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                            } else {
                                Text(String(localized: "Project indexed", table: "QuickFileSearch"))
                                    .font(.appBody)
                                    .foregroundColor(theme.textPrimary)
                                Text(projectVM.currentProjectName)
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }

                        Spacer()
                    }
                }

                if !projectVM.currentProjectPath.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(theme.info)
                        Text(String(localized: "File indexing is automatic when switching projects", table: "QuickFileSearch"))
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
                title: String(localized: "How to Use", table: "QuickFileSearch"),
                spacing: 8
            ) {
                instructionRow(key: "Cmd+P", description: String(localized: "Open file search", table: "QuickFileSearch"))
                instructionRow(key: "↑ ↓", description: String(localized: "Navigate results", table: "QuickFileSearch"))
                instructionRow(key: "Enter", description: String(localized: "Select file", table: "QuickFileSearch"))
                instructionRow(key: "Esc", description: String(localized: "Close search", table: "QuickFileSearch"))
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
    QuickFileSearchSettingsView()
        .inRootView()
        .frame(width: 600, height: 500)
}
