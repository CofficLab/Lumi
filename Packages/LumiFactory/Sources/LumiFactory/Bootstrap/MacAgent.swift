import AppKit
import Combine
import Foundation
import SuperLogKit
import os

/// macOS app delegate: handles external project opening (Dock drag, `open -a Lumi`, URL Scheme, etc.)
@MainActor
public final class MacAgent: NSObject, NSApplicationDelegate, ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.mac-agent")
    nonisolated public static let emoji = "🍎"
    nonisolated static let verbose = false

    @Published public var pendingOpenPath: String?

    public func applicationWillFinishLaunching(_ notification: Notification) {
        // Use application(_:openFile:) / application(_:open:) to receive paths,
        // avoiding interception of kAEOpenDocuments which would prevent SwiftUI
        // WindowGroup from creating windows on cold launch.
    }

    /// App launch completed: trigger one app-level bootstrap side effect.
    /// Feed detection was originally in RootContainer.init, but it's an "app-level
    /// one-shot" action, so it belongs in the app delegate lifecycle alongside
    /// applicationWillTerminate/resignActive.
    ///
    /// Update feed detection is now handled by `AppUpdatePlugin.onBoot()`,
    /// keeping MacAgent decoupled from specific plugins.
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Update feed detection is handled by AppUpdatePlugin.onBoot().
        renameStandardMenuTitles()
    }

    /// SwiftUI 默认菜单(File / Edit / View / Window / Help)走框架自带本地化,
    /// 不读 app 的 xcstrings,且 SwiftUI 会持续重置其管控的 NSMenuItem.title。
    /// 直接改 title 会被下一秒覆盖,必须创建全新的 NSMenuItem 替换原有对象,
    /// 将 submenu 转移过去 —— 新对象不受 SwiftUI 内部绑定,标题不会回弹。
    private func renameStandardMenuTitles() {
        let translations: [String: String] = [
            "File": "文件", "Edit": "编辑", "View": "视图",
            "Window": "窗口", "Help": "帮助",
        ]
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            guard let mainMenu = NSApplication.shared.mainMenu else { return }
            // 先收集匹配项,再倒序替换,避免边遍历边改数组导致索引漂移。
            var toReplace: [(Int, String)] = []
            for (index, item) in mainMenu.items.enumerated() {
                if let localized = translations[item.title] {
                    toReplace.append((index, localized))
                }
            }
            for (index, localized) in toReplace.reversed() {
                let oldItem = mainMenu.items[index]
                let newItem = NSMenuItem(title: localized, action: nil, keyEquivalent: "")
                newItem.submenu = oldItem.submenu
                mainMenu.removeItem(oldItem)
                mainMenu.insertItem(newItem, at: index)
            }
        }
    }

    public func application(_ application: NSApplication, open urls: [URL]) {
        guard Self.verbose else {
            for url in urls {
                if url.isFileURL {
                    let resolvedPath = url.standardized.path
                    setOpenPath(resolvedPath)
                } else if let path = resolvePath(fromOpenURL: url) {
                    setOpenPath(path)
                }
            }
            activateMainWindow()
            return
        }
        Self.logger.info("\(self.t)Received \(urls.count) URL requests")
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
        guard Self.verbose else {
            let path = (filename as NSString).standardizingPath
            setOpenPath(path)
            activateMainWindow()
            return true
        }
        Self.logger.info("\(self.t)Received file open request: \(filename)")
        let path = (filename as NSString).standardizingPath
        setOpenPath(path)
        activateMainWindow()
        return true
    }

    /// App is about to terminate: save all window editors' unsaved content (data safety net).
    /// Regardless of auto-save mode, try to avoid losing editing成果 on exit.
    public func applicationWillTerminate(_ notification: Notification) {
    }

    /// App entered background (lost active state): only trigger save in onWindowChange mode.
    public func applicationDidResignActive(_ notification: Notification) {

    }

    private func resolvePath(fromOpenURL url: URL) -> String? {
        guard url.isFileURL || url.scheme == "file" else { return nil }
        return url.standardized.path
    }

    private func setOpenPath(_ path: String) {
        let normalized = (path as NSString).standardizingPath
        guard !normalized.isEmpty else {
            Self.logger.warning("\(self.t)Path is empty or invalid")
            return
        }
        guard Self.verbose else {
            pendingOpenPath = normalized
            return
        }
        Self.logger.info("\(self.t)Set pending open path: \(normalized)")
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
