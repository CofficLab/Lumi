import FactoryBookletMaker
import FactoryCore
import SwiftUI

@main
struct BookletMakerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: MacAgent

    var body: some Scene {
        WindowGroup("BookletMaker", id: "booklet-maker.main") {
            // FactoryBookletMaker 在编译期确定 16 个插件的最小目录，
            // 不再链接 MLX / 数据库 / 全量 LLM Provider。
            FactoryBookletMaker.makeMainWindow()
                .environmentObject(appDelegate)
                .onReceive(appDelegate.$pendingOpenPath.compactMap { $0 }) { path in
                    OpenProjectHandler.shared.requestOpen(path: path)
                    appDelegate.pendingOpenPath = nil

                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows.first(where: \.canBecomeKey)?.makeKeyAndOrderFront(nil)
                    }
                }
        }
        .handlesExternalEvents(matching: Set())
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1100, height: 760)
        .commands {
            FactoryBookletMaker.makeCommands()
        }

        // ActivityBar 目前使用这个稳定 ID 打开设置窗口；独立进程中可安全复用。
        Window("设置", id: AppBootstrap.settingsWindowID) {
            FactoryBookletMaker.makeSettingsWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 780, height: 600)
    }
}
