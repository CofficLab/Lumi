import AppKit
import Combine
import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// macOS 应用代理：处理外部打开项目（Dock 拖拽、`open -a Lumi`、URL Scheme 等）
@MainActor
final class MacAgent: NSObject, NSApplicationDelegate, ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.mac-agent")
    nonisolated static let emoji = "🍎"
    nonisolated static let verbose = true

    @Published var pendingOpenPath: String?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // 使用 application(_:openFile:) / application(_:open:) 接收路径，
        // 避免拦截 kAEOpenDocuments 导致 SwiftUI WindowGroup 冷启动不创建窗口。
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard Self.verbose else { return }
        Self.logger.info("\(self.t)接收 \(urls.count) 个 URL 请求")
        for url in urls {
            if url.isFileURL {
                let resolvedPath = url.standardized.path
                setOpenPath(resolvedPath)
            } else if let path = resolvePath(fromOpenURL: url) {
                setOpenPath(path)
            }
        }
        activateMainWindow()
    }

    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        guard Self.verbose else { return true }
        Self.logger.info("\(self.t)接收文件打开请求: \(filename)")
        let path = (filename as NSString).standardizingPath
        setOpenPath(path)
        activateMainWindow()
        return true
    }

    private func resolvePath(fromOpenURL url: URL) -> String? {
        guard url.isFileURL || url.scheme == "file" else { return nil }
        return url.standardized.path
    }

    private func setOpenPath(_ path: String) {
        let normalized = (path as NSString).standardizingPath
        guard !normalized.isEmpty else {
            Self.logger.warning("\(self.t)路径为空或无效")
            return
        }
        guard Self.verbose else {
            pendingOpenPath = normalized
            return
        }
        Self.logger.info("\(self.t)设置待打开路径: \(normalized)")
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
