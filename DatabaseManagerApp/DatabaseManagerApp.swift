import AppKit
import FactoryDatabaseManager2
import KernelCore
import SwiftUI

@MainActor
private final class DatabaseManagerFileOpenAgent: NSObject, NSApplicationDelegate {
    private static var kernel: KernelCoreContainer?
    private static var pendingURLs: [URL] = []

    static func configure(kernel: KernelCoreContainer) {
        Self.kernel = kernel
        let queuedURLs = Self.pendingURLs
        Self.pendingURLs = []
        queuedURLs.forEach { _ = FactoryDatabaseManager2.openExternalFile($0, kernel: kernel) }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { Self.open(url) }
    }

    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        Self.open(URL(fileURLWithPath: filename))
        return true
    }

    private static func open(_ url: URL) {
        guard let kernel else {
            pendingURLs.append(url)
            return
        }
        _ = FactoryDatabaseManager2.openExternalFile(url, kernel: kernel)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: \.canBecomeKey)?.makeKeyAndOrderFront(nil)
    }
}

@main
struct DatabaseManagerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: DatabaseManagerFileOpenAgent

    private let mainView: AnyView
    private let settingsView: AnyView

    init() {
        guard let kernel = try? FactoryDatabaseManager2.makeKernel() else {
            mainView = AnyView(Text("Failed to assemble Database Manager"))
            settingsView = AnyView(Text("Failed to assemble settings"))
            return
        }
        DatabaseManagerFileOpenAgent.configure(kernel: kernel)
        mainView = (try? FactoryDatabaseManager2.makeMainView(kernel: kernel))
            ?? AnyView(Text("Failed to assemble Database Manager"))
        settingsView = (try? FactoryDatabaseManager2.makeSettingsView(kernel: kernel))
            ?? AnyView(Text("Failed to assemble settings"))
    }

    var body: some Scene {
        WindowGroup("DatabaseManager", id: "database-manager.main") {
            mainView
        }
        .defaultSize(width: 1100, height: 760)

        Window("设置", id: "database-manager.settings") {
            settingsView
        }
        .defaultSize(width: 780, height: 600)
    }
}
