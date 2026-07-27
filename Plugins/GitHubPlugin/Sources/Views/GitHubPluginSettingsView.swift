import LumiUI
import SuperLogKit
import SwiftUI
import LumiKernel

/// GitHub 插件设置视图 - 配置 GitHub Token 和 API 选项
public struct GitHubPluginSettingsView: View, SuperLog {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public nonisolated static let emoji = "🐙"
    public nonisolated static let verbose: Bool = true

    @State private var token: String = ""
    @State private var isSaved: Bool = false
    @State private var apiLimitInfo: String = "未认证"
    @State private var isLoadingSettings: Bool = false

    private let settingsStore = GitHubPluginLocalStore()
    private let tokenKey = "GitHubToken"

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("GitHub Tools", bundle: .module),
            showHeader: false
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
                title: LumiPluginLocalization.string("Personal Access Token", bundle: .module),
                spacing: 12
            ) {
                AppSettingsSecureFieldRow(
                    LumiPluginLocalization.string("GitHub Token", bundle: .module),
                    placeholder: LumiPluginLocalization.string("Enter GitHub Token", bundle: .module),
                    text: $token
                )

                if isSaved {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.success)
                        Text(LumiPluginLocalization.string("已保存", bundle: .module))
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
                title: LumiPluginLocalization.string("API 限制", bundle: .module),
                subtitle: LumiPluginLocalization.string("Personal Access Token 将存储在本地，用于访问私有仓库和提高 API 限额。", bundle: .module),
                spacing: 12
            ) {
                limitRow(
                    title: LumiPluginLocalization.string("未认证用户", bundle: .module),
                    value: LumiPluginLocalization.string("60 次/小时", bundle: .module),
                    isPositive: false
                )
                limitRow(
                    title: LumiPluginLocalization.string("已认证用户", bundle: .module),
                    value: LumiPluginLocalization.string("5,000 次/小时", bundle: .module),
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
        isLoadingSettings = true
        settingsStore.migrateLegacyValueIfMissing(forKey: tokenKey)
        token = settingsStore.string(forKey: tokenKey) ?? ""
        apiLimitInfo = token.isEmpty ? "未认证" : "已认证"
        isSaved = false
        DispatchQueue.main.async {
            isLoadingSettings = false
        }

        if Self.verbose, GitHubPlugin.verbose {
            GitHubPlugin.logger.info("\(self.t)Token 加载状态：\(apiLimitInfo)")
        }
    }

    private func saveToken() {
        guard !isLoadingSettings else { return }
        settingsStore.set(token, forKey: tokenKey)
        apiLimitInfo = token.isEmpty ? "未认证" : "已认证"

        if !isSaved {
            isSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isSaved = false
            }
        }

        if Self.verbose, GitHubPlugin.verbose {
            GitHubPlugin.logger.info("\(self.t)Token 已保存，认证状态：\(apiLimitInfo)")
        }
    }
}

// MARK: - Event Handler

extension GitHubPluginSettingsView {
    public func onAppear() {
        loadToken()
    }
}

#Preview("App - Small Screen") {
    GitHubPluginSettingsView()
        .frame(width: 500, height: 600)
}

#Preview("App - Big Screen") {
    GitHubPluginSettingsView()
        .frame(width: 1200, height: 1200)
}
