import AppKit
import Combine
import EditorPanelPlugin
import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// macOS 应用代理：处理外部打开项目（Dock 拖拽、`open -a Lumi`、URL Scheme 等）
@MainActor
public final class MacAgent: NSObject, NSApplicationDelegate, ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.mac-agent")
    nonisolated public static let emoji = "🍎"
    nonisolated static let verbose = false

    @Published public var pendingOpenPath: String?

    public func applicationWillFinishLaunching(_ notification: Notification) {
        // 使用 application(_:openFile:) / application(_:open:) 接收路径，
        // 避免拦截 kAEOpenDocuments 导致 SwiftUI WindowGroup 冷启动不创建窗口。
    }

    public func application(_ application: NSApplication, open urls: [URL]) {
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

    public func application(_ application: NSApplication, openFile filename: String) -> Bool {
        guard Self.verbose else { return true }
        Self.logger.info("\(self.t)接收文件打开请求: \(filename)")
        let path = (filename as NSString).standardizingPath
        setOpenPath(path)
        activateMainWindow()
        return true
    }

    /// 应用即将退出：保存所有窗口编辑器的未保存内容（数据安全网）。
    /// 无论自动保存模式如何，都尽力避免退出时丢失编辑成果。
    public func applicationWillTerminate(_ notification: Notification) {
        EditorRuntimeBridge.editorService?.files.saveNowIfNeeded(reason: "app_will_terminate")
    }

    /// 应用进入后台（失去活跃状态）：仅在 onWindowChange 模式下触发保存。
    public func applicationDidResignActive(_ notification: Notification) {
        guard let files = EditorRuntimeBridge.editorService?.files,
              files.autoSaveMode.respondsToWindowChange else { return }
        files.triggerAutoSave(reason: "app_resign_active")
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
