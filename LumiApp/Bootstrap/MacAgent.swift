import AppKit
import Combine
import Foundation
import LumiCoreKit

/// macOS 应用代理：处理外部打开项目（Dock 拖拽、`open -a Lumi`、URL Scheme 等）
@MainActor
final class MacAgent: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var pendingOpenPath: String?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // 使用 application(_:openFile:) / application(_:open:) 接收路径，
        // 避免拦截 kAEOpenDocuments 导致 SwiftUI WindowGroup 冷启动不创建窗口。
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.isFileURL {
                let resolvedPath = OpenProjectPathResolver.resolveProjectRoot(from: url.path)
                setOpenPath(resolvedPath)
            } else if let path = OpenProjectPathResolver.resolvePath(fromOpenURL: url) {
                setOpenPath(path)
            }
        }
        activateMainWindow()
    }

    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        let path = OpenProjectPathResolver.resolveProjectRoot(from: filename)
        setOpenPath(path)
        activateMainWindow()
        return true
    }

    private func setOpenPath(_ path: String) {
        let normalized = OpenProjectPathResolver.normalizePath(path)
        guard !normalized.isEmpty else { return }
        pendingOpenPath = normalized
    }

    private func activateMainWindow() {
        attemptActivate(retries: 5)
    }

    private func attemptActivate(retries: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let window = NSApp.windows.first(where: { $0.canBecomeKey }) else {
                if retries > 0 {
                    Task { @MainActor in
                        self.attemptActivate(retries: retries - 1)
                    }
                }
                return
            }

            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}
