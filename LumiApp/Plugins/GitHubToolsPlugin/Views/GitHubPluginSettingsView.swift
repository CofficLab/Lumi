import SwiftUI

/// GitHub 插件设置视图
struct GitHubPluginSettingsView: View {
    @State private var token: String = ""
    @State private var isSaved: Bool = false
    @State private var showToken: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // GitHub Token 设置卡片
            MystiqueGlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    // 标题
                    Text("GitHub 认证")
                        .font(DesignTokens.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    // Token 输入框
                    Group {
                        if showToken {
                            TextField("Personal Access Token", text: $token)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Personal Access Token", text: $token)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // 操作按钮和显示开关
                    HStack(spacing: 12) {
                        Button("保存 Token") {
                            saveToken()
                        }
                        .buttonStyle(.borderedProminent)

                        Toggle("显示 Token", isOn: $showToken)

                        if isSaved {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }

                    // 帮助链接
                    Link(
                        "如何创建 Personal Access Token？",
                        destination: URL(string: "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens")!
                    )
                    .font(.caption)
                }
                .padding()
            }

            // API 限制说明卡片
            MystiqueGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(DesignTokens.Color.semantic.info)
                            .font(.headline)

                        Text("API 限制")
                            .font(DesignTokens.Typography.bodyEmphasized)
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("未认证用户：")
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            Text("60 次/小时")
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                .fontWeight(.medium)
                        }
                        .font(.caption)

                        HStack {
                            Text("已认证用户：")
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            Text("5000 次/小时")
                                .foregroundColor(DesignTokens.Color.semantic.success)
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                    }

                    Text("Personal Access Token 将存储在本地，用于访问私有仓库和提高 API 限额。")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        .lineLimit(2)
                }
                .padding()
            }
        }
        .padding()
        .onAppear {
            loadToken()
        }
    }

    private func saveToken() {
        UserDefaults.standard.set(token, forKey: "GitHubToken")
        isSaved = true

        // 延迟重置保存状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSaved = false
        }
    }

    private func loadToken() {
        token = UserDefaults.standard.string(forKey: "GitHubToken") ?? ""
    }
}

#Preview {
    GitHubPluginSettingsView()
        .frame(width: 500, height: 400)
}
