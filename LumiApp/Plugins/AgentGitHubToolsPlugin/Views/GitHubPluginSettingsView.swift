import LumiUI
import SwiftUI

/// GitHub 插件设置视图 - 配置 GitHub Token 和 API 选项
struct GitHubPluginSettingsView: View, SuperLog {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    nonisolated static let emoji = "🐙"
    nonisolated static let verbose: Bool = false

    @State private var token: String = ""
    @State private var isSaved: Bool = false
    @State private var apiLimitInfo: String = "未认证"

    private let settingsStore = GitHubPluginLocalStore()
    private let tokenKey = "GitHubToken"

    var body: some View {
        PluginSettingsScaffold(
            title: String(localized: "GitHub Tools", table: "GitHubTools"),
            subtitle: String(localized: "提供访问 GitHub API 的 Agent 工具（仓库/文件/搜索/Issue 管理）", table: "GitHubTools")
        ) {
            tokenCard
            apiLimitCard
        }
        .onAppear(perform: onAppear)
        .onChange(of: token) { _, _ in
            saveToken()
        }
    }

    private var tokenCard: some View {
        AppCard {
            AppSettingsSection(
                title: String(localized: "Personal Access Token", table: "GitHubTools"),
                spacing: 12
            ) {
                AppSettingsSecureFieldRow(
                    String(localized: "GitHub Token", table: "GitHubTools"),
                    placeholder: String(localized: "Enter GitHub Token", table: "GitHubTools"),
                    text: $token
                )

                if isSaved {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.success)
                        Text(String(localized: "已保存", table: "GitHubTools"))
                            .font(.appCaption)
                            .foregroundColor(theme.success)
                    }
                    .padding(.horizontal, 8)
                }

                Link(
                    "如何创建 Personal Access Token？",
                    destination: URL(string: "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens")!
                )
                .font(.appCaption)
                .foregroundColor(theme.primary)
            }
        }
    }

    private var apiLimitCard: some View {
        AppCard {
            AppSettingsSection(
                title: String(localized: "API 限制", table: "GitHubTools"),
                subtitle: String(localized: "Personal Access Token 将存储在本地，用于访问私有仓库和提高 API 限额。", table: "GitHubTools"),
                spacing: 12
            ) {
                limitRow(
                    title: String(localized: "未认证用户", table: "GitHubTools"),
                    value: String(localized: "60 次/小时", table: "GitHubTools"),
                    isPositive: false
                )
                limitRow(
                    title: String(localized: "已认证用户", table: "GitHubTools"),
                    value: String(localized: "5,000 次/小时", table: "GitHubTools"),
                    isPositive: true
                )

                Text(apiLimitInfo)
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    private func limitRow(title: String, value: String, isPositive: Bool) -> some View {
        AppSettingsRow {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                    Text(value)
                        .font(.appBodyEmphasized)
                        .foregroundColor(isPositive ? theme.success : theme.textPrimary)
                }

                Spacer()

                Image(systemName: isPositive ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isPositive ? theme.success : theme.error)
            }
        }
    }
}

// MARK: - Action

extension GitHubPluginSettingsView {
    private func loadToken() {
        settingsStore.migrateLegacyValueIfMissing(forKey: tokenKey)
        token = settingsStore.string(forKey: tokenKey) ?? ""
        apiLimitInfo = token.isEmpty ? "未认证" : "已认证"

        if Self.verbose, GitHubToolsPlugin.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)Token 加载状态：\(apiLimitInfo)")
        }
    }

    private func saveToken() {
        settingsStore.set(token, forKey: tokenKey)
        apiLimitInfo = token.isEmpty ? "未认证" : "已认证"

        if !isSaved {
            isSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isSaved = false
            }
        }

        if Self.verbose, GitHubToolsPlugin.verbose {
            GitHubToolsPlugin.logger.info("\(self.t)Token 已保存，认证状态：\(apiLimitInfo)")
        }
    }
}

// MARK: - Event Handler

extension GitHubPluginSettingsView {
    func onAppear() {
        loadToken()
    }
}

#Preview("App - Small Screen") {
    GitHubPluginSettingsView()
        .inRootView()
        .frame(width: 500, height: 600)
}

#Preview("App - Big Screen") {
    GitHubPluginSettingsView()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
