import Foundation
import LumiKernel
import SuperLogKit
import os

@MainActor
public final class OpenProjectHandler: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.open-project")
    nonisolated public static let emoji = "📂"
    nonisolated static let verbose = false

    public static let shared = OpenProjectHandler()

    /// Injected after `WindowMain` initializes the kernel. Kept optional because
    /// `OpenProjectHandler` is a singleton while `LumiKernel` is created late in
    /// the app launch sequence.
    private weak var kernel: LumiKernel?
    private var pendingPaths: [String] = []

    private init() {}

    /// Called by `WindowMain.initializeContainer` after obtaining the `LumiKernel`.
    public func configure(kernel: LumiKernel) {
        self.kernel = kernel

        // Dock drops can arrive before WindowMain has finished creating the
        // kernel. Replay them after dependency injection instead of losing the
        // request during cold launch.
        let paths = pendingPaths
        pendingPaths.removeAll()
        for path in paths {
            routeOpen(path: path, using: kernel)
        }
    }

    public func requestOpen(path: String) {
        let normalized = Self.normalizePath(path)
        guard !normalized.isEmpty else {
            Self.logger.warning("\(Self.t)Path is empty or invalid: \(path)")
            return
        }

        guard FileManager.default.fileExists(atPath: normalized) else {
            Self.logger.warning("\(Self.t)File does not exist: \(normalized)")
            return
        }

        guard let kernel else {
            pendingPaths.append(normalized)
            Self.logger.info("\(Self.t)LumiKernel not ready, queued external project: \(normalized)")
            return
        }

        routeOpen(path: normalized, using: kernel)
    }

    /// 外部打开请求的统一路由：
    /// - 目录：沿用原有语义，作为项目目录打开。
    /// - 文件：分发给已启用的插件（如 DatabaseManager 接管 .sqlite），无插件接管时记日志忽略。
    private func routeOpen(path: String, using kernel: LumiKernel) {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            openProject(path: path, using: kernel)
        } else {
            openFile(path: path, using: kernel)
        }
    }

    private func openFile(path: String, using kernel: LumiKernel) {
        let url = URL(fileURLWithPath: path)
        Self.logger.info("\(Self.t)Dispatching external file to plugins: \(path)")
        let handled = kernel.pluginManager.dispatchOpenFile(url, kernel: kernel)
        if !handled {
            Self.logger.warning("\(Self.t)No plugin handled external file: \(path)")
        }
    }

    private func openProject(path: String, using kernel: LumiKernel) {
        guard let projectComponent = kernel.project else {
            Self.logger.warning("\(Self.t)Project service not ready, cannot switch project: \(path)")
            return
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)External open project: \(path)")
        }
        Task {
            do {
                try await projectComponent.openProject(at: path)
            } catch {
                Self.logger.error("\(Self.t)Failed to open external project \(path): \(error.localizedDescription)")
            }
        }
    }

    private static func normalizePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return url.path
    }
}
