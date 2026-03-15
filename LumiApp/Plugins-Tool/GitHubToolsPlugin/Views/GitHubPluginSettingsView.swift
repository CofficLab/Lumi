import SwiftUI
import MagicKit
import OSLog

/// GitHub 插件设置视图 - 配置 GitHub Token 和 API 选项
struct GitHubPluginSettingsView: View, SuperLog {
    // MARK: - SuperLog

    nonisolated static let emoji = "🐙"
    nonisolated static let verbose = false

    // MARK: - State

    /// GitHub Token 输入
    @State private var token: String = ""

    /// 是否已保存
    @State private var isSaved: Bool = false

    /// API 限制信息
    @State private var apiLimitInfo: String = "未认证"

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                // GitHub 信息卡片
                githubInfoCard

                // Token 配置
                tokenSection

                // API 限制说明
                apiLimitCard

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
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
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignTokens.Color.semantic.primary, DesignTokens.Color.semantic.primarySecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignTokens.Color.semantic.primary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("GitHub Tools")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Text("提供访问 GitHub API 的 Agent 工具（仓库/文件/搜索/Issue 管理）")
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Material.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    /// Token 配置区域 - 提供文本输入框供用户输入 GitHub Token
    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Personal Access Token")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            // Token 输入框（明文显示）
            TextField("输入 GitHub Token", text: $token)
                .textFieldStyle(.plain)
                .textContentType(.password)
                .font(DesignTokens.Typography.body)
                .padding(DesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(DesignTokens.Material.glass)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )

            // 保存状态
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isSaved {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignTokens.Color.semantic.success)
                            .font(.caption)
                        Text("已保存")
                            .font(.caption)
                            .foregroundColor(DesignTokens.Color.semantic.success)
                    }
                }
            }

            // 帮助链接
            Link(
                "如何创建 Personal Access Token？",
                destination: URL(string: "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens")!
            )
            .font(DesignTokens.Typography.caption1)
            .foregroundColor(DesignTokens.Color.semantic.primary)
        }
    }

    /// API 限制说明卡片
    private var apiLimitCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(DesignTokens.Color.semantic.info)
                    .font(.headline)

                Text("API 限制")
                    .font(DesignTokens.Typography.bodyEmphasized)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            }

            VStack(spacing: DesignTokens.Spacing.sm) {
                // 未认证限制
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("未认证用户")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text("60 次/小时")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DesignTokens.Color.semantic.error)
                        .font(.title2)
                }
                .padding(DesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                .stroke(DesignTokens.Color.semantic.error.opacity(0.3), lineWidth: 1)
                        )
                )

                // 已认证限制
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已认证用户")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text("5,000 次/小时")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Color.semantic.success)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Color.semantic.success)
                        .font(.title2)
                }
                .padding(DesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(DesignTokens.Color.semantic.success.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                .stroke(DesignTokens.Color.semantic.success.opacity(0.3), lineWidth: 1)
                        )
                )
            }

            Text("Personal Access Token 将存储在本地，用于访问私有仓库和提高 API 限额。")
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                .lineLimit(2)
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Material.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Action

extension GitHubPluginSettingsView {
    /// 加载 GitHub Token
    private func loadToken() {
        token = AppSettingsStore.shared.string(forKey: "GitHubToken") ?? ""
        apiLimitInfo = token.isEmpty ? "未认证" : "已认证"

        if Self.verbose {
            os_log("\(Self.emoji) Token 加载状态：\(apiLimitInfo)")
        }
    }

    /// 保存 GitHub Token 到 UserDefaults
    private func saveToken() {
        AppSettingsStore.shared.set(token, forKey: "GitHubToken")
        apiLimitInfo = token.isEmpty ? "未认证" : "已认证"

        if !isSaved {
            isSaved = true

            // 延迟重置保存状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isSaved = false
            }
        }

        if Self.verbose {
            os_log("\(Self.emoji) Token 已保存，认证状态：\(apiLimitInfo)")
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
