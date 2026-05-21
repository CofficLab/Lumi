import SwiftUI

/// GitHub 插件设置视图 - 配置 GitHub Token 和 API 选项
struct GitHubPluginSettingsView: View, SuperLog {
    // MARK: - SuperLog

    nonisolated static let emoji = "🐙"
    nonisolated static let verbose: Bool = false
    // MARK: - State

    /// GitHub Token 输入
    @State private var token: String = ""

    /// 是否已保存
    @State private var isSaved: Bool = false

    /// API 限制信息
    @State private var apiLimitInfo: String = "未认证"
    private let settingsStore = GitHubPluginLocalStore()
    private let tokenKey = "GitHubToken"

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // GitHub 信息卡片
                githubInfoCard

                // Token 配置
                tokenSection

                // API 限制说明
                apiLimitCard

                Spacer()
            }
            .padding(24)
        }
        .onAppear(perform: onAppear)
        .onChange(of: token) { _, _ in
            saveToken()
        }
    }
}

// MARK: - View

extension GitHubPluginSettingsView {
    /// GitHub 信息卡片 - 显示插件图标、名称和描述
    private var githubInfoCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "7C6FFF"), Color(hex: "A99CFF")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "7C6FFF").opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "GitHub Tools", table: "GitHubTools"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Text(String(localized: "提供访问 GitHub API 的 Agent 工具（仓库/文件/搜索/Issue 管理）", table: "GitHubTools"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Material.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    /// Token 配置区域 - 提供文本输入框供用户输入 GitHub Token
    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Personal Access Token", table: "GitHubTools"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            // Token 输入框（明文显示）
            TextField("输入 GitHub Token", text: $token)
                .textFieldStyle(.plain)
                .textContentType(.password)
                .font(.system(size: 15, weight: .regular))
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Material.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )

            // 保存状态
            HStack(spacing: 8) {
                if isSaved {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "30D158"))
                            .font(.caption)
                        Text(String(localized: "已保存", table: "GitHubTools"))
                            .font(.caption)
                            .foregroundColor(Color(hex: "30D158"))
                    }
                }
            }

            // 帮助链接
            Link(
                "如何创建 Personal Access Token？",
                destination: URL(string: "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens")!
            )
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(Color(hex: "7C6FFF"))
        }
    }

    /// API 限制说明卡片
    private var apiLimitCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color(hex: "0A84FF"))
                    .font(.system(size: 15, weight: .medium))

                Text(String(localized: "API 限制", table: "GitHubTools"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
            }

            VStack(spacing: 8) {
                // 未认证限制
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "未认证用户", table: "GitHubTools"))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        Text(String(localized: "60 次/小时", table: "GitHubTools"))
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                            .fontWeight(.medium)
                    }

                    Spacer()

                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(hex: "FF453A"))
                        .font(.title2)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "FF453A").opacity(0.3), lineWidth: 1)
                        )
                )

                // 已认证限制
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "已认证用户", table: "GitHubTools"))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        Text(String(localized: "5,000 次/小时", table: "GitHubTools"))
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color(hex: "30D158"))
                            .fontWeight(.medium)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "30D158"))
                        .font(.title2)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "30D158").opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "30D158").opacity(0.3), lineWidth: 1)
                        )
                )
            }

            Text(String(localized: "Personal Access Token 将存储在本地，用于访问私有仓库和提高 API 限额。", table: "GitHubTools"))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(hex: "98989E"))
                .lineLimit(2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Material.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Action

extension GitHubPluginSettingsView {
    /// 加载 GitHub Token
    private func loadToken() {
        settingsStore.migrateLegacyValueIfMissing(forKey: tokenKey)
        token = settingsStore.string(forKey: tokenKey) ?? ""
        apiLimitInfo = token.isEmpty ? "未认证" : "已认证"

        if Self.verbose {
            if GitHubToolsPlugin.verbose {
                            GitHubToolsPlugin.logger.info("\(self.t)Token 加载状态：\(apiLimitInfo)")
            }
        }
    }

    /// 保存 GitHub Token 到插件本地配置
    private func saveToken() {
        settingsStore.set(token, forKey: tokenKey)
        apiLimitInfo = token.isEmpty ? "未认证" : "已认证"

        if !isSaved {
            isSaved = true

            // 延迟重置保存状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isSaved = false
            }
        }

        if Self.verbose {
            if GitHubToolsPlugin.verbose {
                            GitHubToolsPlugin.logger.info("\(self.t)Token 已保存，认证状态：\(apiLimitInfo)")
            }
        }
    }
}

// MARK: - Event Handler

extension GitHubPluginSettingsView {
    /// 视图出现时的事件处理 - 加载 Token
    func onAppear() {
        loadToken()
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    GitHubPluginSettingsView()
        .inRootView()
        .frame(width: 500)
        .frame(height: 600)
}

#Preview("App - Big Screen") {
    GitHubPluginSettingsView()
        .inRootView()
        .frame(width: 1200)
        .frame(height: 1200)
}
