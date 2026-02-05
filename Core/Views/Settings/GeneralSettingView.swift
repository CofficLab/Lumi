import SwiftUI
import ServiceManagement

/// 通用设置视图
struct GeneralSettingView: View {
    /// 是否开机启动
    @State private var launchAtLogin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 40)

                // 开机启动
                VStack(alignment: .leading, spacing: 12) {
                    Text("启动选项")
                        .font(.headline)

                    Toggle("开机启动", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            updateLaunchAtLogin(newValue)
                        }
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .navigationTitle("通用")
        .onAppear {
            checkLaunchAtLoginStatus()
        }
    }

    // MARK: - Launch at Login

    /// 检查当前开机启动状态
    private func checkLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            // 使用新 API
            if let job = try? SMAppService.mainApp.status {
                launchAtLogin = (job == .enabled)
            }
        } else {
            // macOS 12 及更早版本不支持程序化设置
            launchAtLogin = false
        }
    }

    /// 更新开机启动状态
    /// - Parameter enabled: 是否启用
    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            // 使用新 API
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    print("✅ 开机启动已启用")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("❌ 开机启动已禁用")
                }
            } catch {
                print("❌ 更新开机启动失败: \(error.localizedDescription)")
                // 恢复开关状态
                launchAtLogin.toggle()
            }
        } else {
            // macOS 12 及更早版本
            print("⚠️ 开机启动功能需要 macOS 13.0 或更高版本")
            // 恢复开关状态
            launchAtLogin.toggle()
        }
    }
}

// MARK: - Preview

#Preview {
    GeneralSettingView()
}
