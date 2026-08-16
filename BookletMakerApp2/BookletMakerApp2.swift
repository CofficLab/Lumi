import FactoryBookletMaker2
import SwiftUI

/// BookletMakerApp2：基于 FactoryBookletMaker2（KernelCore 新体系）的最小宿主 App。
///
/// App 只需要视图，视图组装（内核装配 + 工具栏/ActivityBar/Rail/内容注入）
/// 全部由 `KernelFactory.makeMainView()` 完成；设置窗口由
/// `KernelFactory.makeSettingsView()` 提供。
@main
struct BookletMakerApp2: App {
    /// 主视图在 `init` 中一次性装配并缓存，绝不能在 `body`（Scene）求值期间调用
    /// `makeMainView()`：它会给 `DefaultRootViewProviding`（ObservableObject）的
    /// `@Published` 属性注入视图，在视图更新期间发布 `objectWillChange` 会触发
    /// SwiftUI 的 "Publishing changes from within view updates is not allowed"，
    /// 且发布经 Kernel 转发后会让 `body` 重新求值 → 再次装配 → 无限循环刷屏。
    private let mainView: AnyView
    private let settingsView: AnyView

    init() {
        mainView = (try? KernelFactory.makeMainView())
            ?? AnyView(Text("Failed to assemble main view"))
        settingsView = (try? KernelFactory.makeSettingsView())
            ?? AnyView(Text("Failed to assemble settings view"))
    }

    var body: some Scene {
        WindowGroup("BookletMaker2", id: "booklet-maker-2.main") {
            mainView
        }
        .defaultSize(width: 1100, height: 760)

        Window("设置", id: "booklet-maker-2.settings") {
            settingsView
        }
        .defaultSize(width: 480, height: 360)
    }
}
