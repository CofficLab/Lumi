import FactoryAppIconDesigner
import KernelCore
import ProviderSettingView
import SwiftUI

@main
struct AppIconDesignerApp: App {
    private let kernel: KernelCoreContainer
    private let mainView: AnyView
    private let settingsView: AnyView
    @Environment(\.openWindow) private var openWindow

    init() {
        if let assembledKernel = try? FactoryAppIconDesigner.makeKernel() {
            kernel = assembledKernel
            mainView = (try? FactoryAppIconDesigner.makeMainView(kernel: assembledKernel))
                ?? AnyView(Text("Failed to assemble App Icon Designer"))
            settingsView = (try? FactoryAppIconDesigner.makeSettingsView(kernel: assembledKernel))
                ?? AnyView(Text("Failed to assemble settings"))
        } else {
            let fallbackKernel = KernelCoreContainer()
            kernel = fallbackKernel
            mainView = AnyView(Text("Failed to assemble App Icon Designer"))
            settingsView = AnyView(Text("Failed to assemble settings"))
        }
    }

    var body: some Scene {
        WindowGroup("AppIconDesigner", id: "app-icon-designer.main") {
            mainView
                .onReceive(NotificationCenter.default.publisher(
                    for: SettingViewNavigation.openSettingsNotification
                )) { notification in
                    if let settings = kernel.resolveProvider((any SettingViewProviding).self),
                       let entryID = notification.userInfo?[SettingViewNavigation.entryIDUserInfoKey] as? String,
                       settings.entries.contains(where: { $0.id == entryID }) {
                        settings.selectEntry(id: entryID)
                    }
                    openWindow(id: "app-icon-designer.settings")
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1100, height: 760)
        .commands {
            AppCommands(kernel: kernel)
        }

        // 与 BookletMaker 使用相同的普通 Window Scene，避免 macOS Settings 容器
        // 额外注入边距/安全区域，导致共享设置视图被裁切。
        Window("设置", id: "app-icon-designer.settings") {
            settingsView
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1000, height: 600)
    }
}
