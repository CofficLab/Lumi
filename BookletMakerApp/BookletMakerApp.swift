import FactoryBookletMaker
import FactoryLumi
import KernelCore
import SwiftUI

@main
struct BookletMakerApp: App {
    private let kernel: KernelCoreContainer
    private let mainView: AnyView
    private let settingsView: AnyView

    init() {
        if let assembledKernel = try? FactoryBookletMaker.makeKernel() {
            kernel = assembledKernel
            mainView = (try? FactoryBookletMaker.makeMainView(kernel: assembledKernel))
                ?? AnyView(Text("Failed to assemble main view"))
            settingsView = (try? FactoryBookletMaker.makeSettingsView(kernel: assembledKernel))
                ?? AnyView(Text("Failed to assemble settings view"))
        } else {
            let fallbackKernel = KernelCoreContainer()
            kernel = fallbackKernel
            mainView = AnyView(Text("Failed to assemble main view"))
            settingsView = AnyView(Text("Failed to assemble settings view"))
        }
    }

    var body: some Scene {
        WindowGroup("BookletMaker", id: "booklet-maker.main") {
            mainView
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1100, height: 760)
        .commands {
            AppCommands(kernel: kernel)
        }

        // 原生 Settings scene 会自动把“设置…”放入 BookletMaker 应用菜单，
        // 并与主窗口共享已装配的内核和插件状态。
        Settings {
            settingsView
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 780, height: 600)
    }
}
