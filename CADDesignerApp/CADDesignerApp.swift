import FactoryCADDesigner
import SwiftUI

@main
struct CADDesignerApp: App {
    private let mainView: AnyView
    private let settingsView: AnyView

    init() {
        guard let kernel = try? FactoryCADDesigner.makeKernel() else {
            mainView = AnyView(Text("Failed to assemble CAD Designer"))
            settingsView = AnyView(Text("Failed to assemble settings"))
            return
        }
        mainView = (try? FactoryCADDesigner.makeMainView(kernel: kernel))
            ?? AnyView(Text("Failed to assemble CAD Designer"))
        settingsView = (try? FactoryCADDesigner.makeSettingsView(kernel: kernel))
            ?? AnyView(Text("Failed to assemble settings"))
    }

    var body: some Scene {
        WindowGroup("CADDesigner", id: "cad-designer.main") {
            mainView
        }
        .defaultSize(width: 1280, height: 860)

        Window("设置", id: "cad-designer.settings") {
            settingsView
        }
        .defaultSize(width: 780, height: 600)
    }
}
