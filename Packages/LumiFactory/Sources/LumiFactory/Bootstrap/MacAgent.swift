import AppKit
import Combine
import EditorService
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
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Update feed detection will be called here when UpdateService is restored.
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
        EditorRuntimeBridge.editorService?.files.saveNowIfNeeded(reason: "app_will_terminate")
    }

    /// App entered background (lost active state): only trigger save in onWindowChange mode.
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
