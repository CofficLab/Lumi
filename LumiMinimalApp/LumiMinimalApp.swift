import FactoryLumi2
import SwiftUI

/// 最小 App：验证「Factory 组装完整主视图 → App 展示窗口」链路。
///
/// App 只需要一个视图，视图组装（内核装配 + 工具栏/ActivityBar/Rail 注入）
/// 全部由 `KernelFactory.makeMainView()` 完成。
@main
struct LumiMinimalApp: App {
    var body: some Scene {
        WindowGroup("LumiMinimal", id: "lumi-minimal.main") {
            // App 只做一件事：让 Factory 给一个视图。
            (try? KernelFactory.makeMainView()) ?? AnyView(Text("Failed to assemble main view"))
        }
        .defaultSize(width: 480, height: 320)
    }
}
