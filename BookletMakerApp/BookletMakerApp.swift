import FactoryBookletMaker2
import FactoryLumi2
import KernelCore
import SwiftUI

@main
struct BookletMakerApp: App {
    @StateObject private var kernel: KernelCoreContainer
    private let mainView: AnyView
    private let settingsView: AnyView

    init() {
        if let assembledKernel = try? FactoryBookletMaker2.makeKernel() {
            _kernel = StateObject(wrappedValue: assembledKernel)
            mainView = (try? FactoryBookletMaker2.makeMainView(kernel: assembledKernel))
                ?? AnyView(Text("Failed to assemble main view"))
            settingsView = (try? FactoryBookletMaker2.makeSettingsView(kernel: assembledKernel))
                ?? AnyView(Text("Failed to assemble settings view"))
        } else {
            let fallbackKernel = KernelCoreContainer()
            _kernel = StateObject(wrappedValue: fallbackKernel)
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

        Window("设置", id: "booklet-maker.settings") {
            settingsView
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 780, height: 600)
    }
}
