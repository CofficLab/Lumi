import AppKit
import Combine
import Foundation
import SuperLogKit
import os

/// macOS 应用代理：处理外部打开项目
@MainActor
public final class MacAgent: NSObject, NSApplicationDelegate, ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.mac-agent")
    nonisolated public static let emoji = "🍎"
    nonisolated static let verbose = false

    @Published public var pendingOpenPath: String?

    public override init() {
        super.init()
    }

    public func applicationWillFinishLaunching(_ notification: Notification) {}

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // TODO: 更新 feed 探测等应用级启动副作用
    }

    public func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.isFileURL {
                let resolvedPath = url.standardized.path
                setOpenPath(resolvedPath)
            }
        }
        activateMainWindow()
    }

    public func application(_ application: NSApplication, openFile filename: String) -> Bool {
        let path = (filename as NSString).standardizingPath
        setOpenPath(path)
        activateMainWindow()
        return true
    }

    private func setOpenPath(_ path: String) {
        let normalized = (path as NSString).standardizingPath
        guard !normalized.isEmpty else { return }
        pendingOpenPath = normalized
    }

    private func activateMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}