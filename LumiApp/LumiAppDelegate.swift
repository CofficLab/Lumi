import AppKit
import Combine
import Foundation

/// V2 application delegate for Launch Services, Finder, and Dock open events.
/// It deliberately contains no legacy KernelLumi/FactoryCore dependency: the
/// path is handed to `KernelFactory` after the shared V2 kernel is ready.
@MainActor
final class LumiAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var pendingOpenPath: String?

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if handleFinderCommand(url) { continue }
            if url.isFileURL {
                pendingOpenPath = url.standardizedFileURL.path
            }
        }
        activateMainWindow()
    }

    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        pendingOpenPath = (filename as NSString).standardizingPath
        activateMainWindow()
        return true
    }

    private func handleFinderCommand(_ url: URL) -> Bool {
        guard url.scheme == Self.urlScheme,
              url.host == "finder",
              url.path == "/show-hidden",
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "value" })?.value,
              let showHiddenFiles = Bool(value) else {
            return false
        }

        let defaults = Process()
        defaults.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        defaults.arguments = [
            "write", "com.apple.finder", "AppleShowAllFiles", "-bool",
            showHiddenFiles ? "true" : "false"
        ]
        try? defaults.run()
        defaults.waitUntilExit()
        guard defaults.terminationStatus == 0 else { return true }

        let restart = Process()
        restart.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        restart.arguments = ["Finder"]
        try? restart.run()
        return true
    }

    private func activateMainWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
        }
    }

    private static var urlScheme: String {
        (Bundle.main.object(forInfoDictionaryKey: "LumiURLScheme") as? String)
            ?? "lumi"
    }
}
