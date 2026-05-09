import SwiftUI
import MagicKit
import os
import XcodeKit

/// Xcode 插件根视图包裹器
@MainActor
struct EditorXcodePluginRootView<Content: View>: View, SuperLog {
    nonisolated static var emoji: String { "🚀" }

    let content: Content

    @EnvironmentObject var projectVM: ProjectVM

    @State private var hasTriggeredPreload = false
    @State private var preloadStatus: PreloadStatus = .idle

    enum PreloadStatus: Sendable {
        case idle
        case loading(count: Int)
        case completed(success: Int, failed: Int)
    }

    var body: some View {
        content
            .onAppear {
                guard !hasTriggeredPreload else { return }
                hasTriggeredPreload = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await preloadRecentXcodeProjects()
                }
            }
    }

    // MARK: - 预加载逻辑

    private func preloadRecentXcodeProjects() async {
        let recentProjects = projectVM.getRecentProjects()
        let xcodeProjects = recentProjects.filter { project in
            XcodeProjectResolver.isXcodeProjectRoot(URL(filePath: project.path))
        }

        guard !xcodeProjects.isEmpty else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(self.t)没有找到最近的 Xcode 项目，跳过预加载")
            }
            return
        }

        let projectsToPreload = Array(xcodeProjects.prefix(3))

        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(self.t)开始预加载 \(projectsToPreload.count) 个最近的 Xcode 项目")
        }

        await MainActor.run {
            self.preloadStatus = .loading(count: projectsToPreload.count)
        }

        await withTaskGroup(of: (project: Project, success: Bool).self) { group in
            var activeTasks = 0
            let maxConcurrentTasks = 2

            for project in projectsToPreload {
                while activeTasks >= maxConcurrentTasks {
                    _ = await group.next()
                    activeTasks -= 1
                }

                group.addTask {
                    let store = XcodeBuildServerStore(storageRootURL: AppConfig.getDBFolderURL())
                    let success = await Self.preloadProject(project, store: store)
                    return (project, success)
                }
                activeTasks += 1
            }

            var successCount = 0
            var failedCount = 0

            for await (project, success) in group {
                if success {
                    successCount += 1
                } else {
                    failedCount += 1
                }
            }

            await MainActor.run {
                self.preloadStatus = .completed(success: successCount, failed: failedCount)
            }

            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(Self.t)预加载完成：\(successCount) 成功，\(failedCount) 失败")
            }
        }
    }

    // MARK: - 单个项目预加载

    private static func preloadProject(_ project: Project, store: XcodeBuildServerStore) async -> Bool {
        let projectURL = URL(filePath: project.path)
        guard let workspaceURL = XcodeProjectResolver.findWorkspace(in: projectURL) else { return false }

        if store.validate(forWorkspace: workspaceURL.path) != nil {
            return true
        }

        return await Task.detached(priority: .background) {
            return await generateBuildServer(for: workspaceURL, projectName: project.name, store: store)
        }.value
    }

    private static func generateBuildServer(for workspaceURL: URL, projectName: String, store: XcodeBuildServerStore) async -> Bool {
        let xcodeBuildServerPaths = [
            "/opt/homebrew/bin/xcode-build-server",
            "/usr/local/bin/xcode-build-server",
        ]

        var xcodeBuildServerPath: String?
        for path in xcodeBuildServerPaths {
            if FileManager.default.fileExists(atPath: path) {
                xcodeBuildServerPath = path
                break
            }
        }

        if xcodeBuildServerPath == nil {
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/which")
            process.arguments = ["xcode-build-server"]
            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0,
                   let data = try? pipe.fileHandleForReading.readDataToEndOfFile(),
                   let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    xcodeBuildServerPath = path
                }
            } catch {}
        }

        guard let serverPath = xcodeBuildServerPath else { return false }

        let schemes = await fetchAvailableSchemes(for: workspaceURL)
        guard let scheme = schemes.first else { return false }

        let outputDirectory = store.ensureDirectory(forWorkspace: workspaceURL.path)

        let isProject = workspaceURL.pathExtension == "xcodeproj"
        let workspaceArg = isProject ? "-project" : "-workspace"
        let args = ["config", workspaceArg, workspaceURL.path, "-scheme", scheme]

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(filePath: serverPath)
            process.arguments = args
            process.currentDirectoryURL = outputDirectory
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { _ in
                continuation.resume(returning: process.terminationStatus == 0)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    private static func fetchAvailableSchemes(for workspaceURL: URL) async -> [String] {
        var args = ["-list", "-json"]
        let isProject = workspaceURL.pathExtension == "xcodeproj"
        let workspaceArg = isProject ? "-project" : "-workspace"
        args += [workspaceArg, workspaceURL.path]

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/xcodebuild")
            process.arguments = args
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { _ in
                guard process.terminationStatus == 0,
                      let data = try? JSONSerialization.jsonObject(with: pipe.fileHandleForReading.readDataToEndOfFile()) as? [String: Any] else {
                    continuation.resume(returning: [])
                    return
                }

                var schemes: [String] = []
                if let project = data["project"] as? [String: Any],
                   let projectSchemes = project["schemes"] as? [String] {
                    schemes.append(contentsOf: projectSchemes)
                }
                if let workspace = data["workspace"] as? [String: Any],
                   let workspaceSchemes = workspace["schemes"] as? [String] {
                    schemes.append(contentsOf: workspaceSchemes)
                }

                continuation.resume(returning: Array(Set(schemes)))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}

#Preview("RootView Wrapper") {
    EditorXcodePluginRootView(content: Text("Content View").padding())
}
