import FactoryBookletMaker
import FactoryLumi
import KernelCore
import SwiftUI

@main
struct BookletMakerApp: App {
    private let kernel: KernelCoreContainer
    private let mainView: AnyView

    init() {
        if let assembledKernel = try? FactoryBookletMaker.makeKernel() {
            kernel = assembledKernel
            mainView = (try? FactoryBookletMaker.makeMainView(kernel: assembledKernel))
                ?? AnyView(Text("Failed to assemble main view"))
        } else {
            let fallbackKernel = KernelCoreContainer()
            kernel = fallbackKernel
            mainView = AnyView(Text("Failed to assemble main view"))
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
    }
}
