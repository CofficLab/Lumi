import FactoryLumi2
import PluginToolbarSettings
import SwiftUI

/// 最小 App：验证「Factory 组装完整主视图 → App 展示窗口」链路。
///
/// App 只需要视图，视图组装（内核装配 + 工具栏/ActivityBar/Rail/内容注入）
/// 全部由 `KernelFactory.makeMainView()` 完成；设置窗口由
/// `KernelFactory.makeSettingsView()` 提供；工具栏设置按钮通过通知
/// （`lumiOpenSettings`）请求打开设置窗口。
@main
struct LumiMinimalApp: App {
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("LumiMinimal", id: "lumi-minimal.main") {
            // App 只做一件事：让 Factory 给一个视图。
            (try? KernelFactory.makeMainView()) ?? AnyView(Text("Failed to assemble main view"))
                // 工具栏「设置」按钮点击后，通知 → 打开设置窗口
                .onReceive(NotificationCenter.default.publisher(for: .lumiOpenSettings)) { _ in
                    openWindow(id: "lumi-minimal.settings")
                }
        }
        .defaultSize(width: 480, height: 320)

        Window("设置", id: "lumi-minimal.settings") {
            (try? KernelFactory.makeSettingsView()) ?? AnyView(Text("Failed to assemble settings view"))
        }
        .defaultSize(width: 360, height: 260)
    }
}
