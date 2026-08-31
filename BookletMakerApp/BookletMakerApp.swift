import FactoryBookletMaker
import KernelCore
import ProviderSettingView
import SwiftUI

@main
struct BookletMakerApp: App {
    private let kernel: KernelCoreContainer
    private let mainView: AnyView
    private let settingsView: AnyView
    @Environment(\.openWindow) private var openWindow

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
                .onReceive(NotificationCenter.default.publisher(
                    for: SettingViewNavigation.openSettingsNotification
                )) { notification in
                    if let settings = kernel.resolveProvider((any SettingViewProviding).self),
                       let entryID = notification.userInfo?[SettingViewNavigation.entryIDUserInfoKey] as? String,
                       settings.entries.contains(where: { $0.id == entryID }) {
                        settings.selectEntry(id: entryID)
                    }
                    openWindow(id: "booklet-maker.settings")
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1100, height: 760)
        .commands {
            AppCommands(kernel: kernel)
            BookletMakerSettingsCommands()
        }

        // 与 Lumi 使用相同的普通 Window Scene，避免 macOS Settings 容器
        // 额外注入边距/安全区域，导致共享设置视图被裁切。
        Window("设置", id: "booklet-maker.settings") {
            settingsView
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1000, height: 600)
    }
}

/// 普通 Window Scene 不会自动生成系统 Settings 命令，因此显式把入口放回
/// 应用菜单，保持“BookletMaker → 设置…”的用户路径。
private struct BookletMakerSettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("设置…") {
                openWindow(id: "booklet-maker.settings")
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}
