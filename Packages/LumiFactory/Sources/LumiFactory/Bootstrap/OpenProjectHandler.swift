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
            openProject(path: path, using: kernel)
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

        openProject(path: normalized, using: kernel)
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
