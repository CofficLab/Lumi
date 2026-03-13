import SwiftUI

/// GitHub 插件设置视图
struct GitHubPluginSettingsView: View {
    @State private var token: String = ""
    @State private var isSaved: Bool = false
    @State private var showToken: Bool = false

    var body: some View {
        Form {
            Section(
                header: Text("GitHub 认证"),
                footer: Text("Personal Access Token 将存储在本地，用于访问私有仓库和提高 API 限额。")
            ) {
                Group {
                    if showToken {
                        TextField("Personal Access Token", text: $token)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Personal Access Token", text: $token)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                HStack {
                    Button("保存 Token") {
                        saveToken()
                    }
                    .buttonStyle(.borderedProminent)

                    Toggle("显示 Token", isOn: $showToken)

                    if isSaved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Link(
                    "如何创建 Personal Access Token？",
                    destination: URL(string: "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens")!
                )
                .font(.caption)
            }

            Section(header: Text("API 限制")) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("未认证用户：60 次/小时")
                    Text("已认证用户：5000 次/小时")
                }
                .font(.caption)
                .foregroundColor(.secondary)
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
        .frame(width: 400, height: 300)
}
