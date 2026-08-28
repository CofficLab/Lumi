import FactoryAppIconDesigner
import SwiftUI

@main
struct AppIconDesignerApp: App {
    private let mainView: AnyView
    private let settingsView: AnyView

    init() {
        guard let kernel = try? FactoryAppIconDesigner.makeKernel() else {
            mainView = AnyView(Text("Failed to assemble App Icon Designer"))
            settingsView = AnyView(Text("Failed to assemble settings"))
            return
        }
        mainView = (try? FactoryAppIconDesigner.makeMainView(kernel: kernel))
            ?? AnyView(Text("Failed to assemble App Icon Designer"))
        settingsView = (try? FactoryAppIconDesigner.makeSettingsView(kernel: kernel))
            ?? AnyView(Text("Failed to assemble settings"))
    }

    var body: some Scene {
        WindowGroup("AppIconDesigner", id: "app-icon-designer.main") {
            mainView
        }
        .defaultSize(width: 1200, height: 900)

        Window("设置", id: "app-icon-designer.settings") {
            settingsView
        }
        .defaultSize(width: 780, height: 600)
    }
}
