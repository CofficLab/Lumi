import FactoryBookletMaker2
import SwiftUI

/// BookletMakerApp2：基于 FactoryBookletMaker2（KernelCore 新体系）的最小宿主 App。
///
/// App 只需要视图，视图组装（内核装配 + 工具栏/ActivityBar/Rail/内容注入）
/// 全部由 `KernelFactory.makeMainView()` 完成；设置窗口由
/// `KernelFactory.makeSettingsView()` 提供。
@main
struct BookletMakerApp2: App {
    var body: some Scene {
        WindowGroup("BookletMaker2", id: "booklet-maker-2.main") {
            // App 只做一件事：让 Factory 给一个视图。
            (try? KernelFactory.makeMainView()) ?? AnyView(Text("Failed to assemble main view"))
        }
        .defaultSize(width: 1100, height: 760)

        Window("设置", id: "booklet-maker-2.settings") {
            (try? KernelFactory.makeSettingsView()) ?? AnyView(Text("Failed to assemble settings view"))
        }
        .defaultSize(width: 480, height: 360)
    }
}
