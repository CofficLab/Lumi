import LumiUI
import LumiCoreKit
import SwiftUI

/// 快速文件搜索设置视图
public struct QuickFileSearchSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectContext: PluginProjectContext

    public var body: some View {
        PluginSettingsScaffold(
            title: String(localized: "Quick File Search", bundle: .module),
            subtitle: String(localized: "Fast file search with Cmd+P", bundle: .module),
            showHeader: false
        ) {
            statusCard
            instructionsCard
        }
    }

    private var statusCard: some View {
        AppCard {
            AppSettingsSection(
                title: String(localized: "Current Status", bundle: .module),
                spacing: 12
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: projectContext.currentProjectPath.isEmpty ? "circle" : "checkmark.circle.fill")
                            .font(.appTitle)
                            .foregroundColor(projectContext.currentProjectPath.isEmpty ? theme.warning : theme.success)

                        VStack(alignment: .leading, spacing: 4) {
                            if projectContext.currentProjectPath.isEmpty {
                                Text(String(localized: "No project selected", bundle: .module))
                                    .font(.appBody)
                                    .foregroundColor(theme.textPrimary)
                                Text(String(localized: "Please select a project to enable file search", bundle: .module))
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                            } else {
                                Text(String(localized: "Project indexed", bundle: .module))
                                    .font(.appBody)
                                    .foregroundColor(theme.textPrimary)
                                Text(projectContext.currentProjectName)
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }

                        Spacer()
                    }
                }

                if !projectContext.currentProjectPath.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(theme.info)
                        Text(String(localized: "File indexing is automatic when switching projects", bundle: .module))
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
                title: String(localized: "How to Use", bundle: .module),
                spacing: 8
            ) {
                instructionRow(key: "Cmd+P", description: String(localized: "Open file search", bundle: .module))
                instructionRow(key: "↑ ↓", description: String(localized: "Navigate results", bundle: .module))
                instructionRow(key: "Enter", description: String(localized: "Select file", bundle: .module))
                instructionRow(key: "Esc", description: String(localized: "Close search", bundle: .module))
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
