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
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(Self.t)RootView onAppear")
                }
                guard !hasTriggeredPreload else {
                    if XcodePluginLog.verbose {
                        XcodePluginLog.logger.info("\(Self.t)预加载已触发过，跳过")
                    }
                    return
                }
                hasTriggeredPreload = true
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(Self.t)准备延迟 3 秒后预加载最近 Xcode 项目")
                }
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await preloadRecentXcodeProjects()
                }
            }
    }

    // MARK: - 预加载逻辑

    private func preloadRecentXcodeProjects() async {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(Self.t)开始扫描最近项目用于 Xcode 预加载")
        }
        let recentProjects = projectVM.getRecentProjects()
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(Self.t)最近项目数量：\(recentProjects.count)")
        }
        let xcodeProjects = await EditorXcodeProjectPreloader.filterXcodeProjects(recentProjects)

        guard !xcodeProjects.isEmpty else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(Self.t)没有找到最近的 Xcode 项目，跳过预加载")
            }
            return
        }

        let projectsToPreload = Array(xcodeProjects.prefix(3))

        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(Self.t)开始预加载 \(projectsToPreload.count) 个最近的 Xcode 项目：\(projectsToPreload.map(\.name).joined(separator: ", "))")
        }

        await MainActor.run {
            self.preloadStatus = .loading(count: projectsToPreload.count)
        }

        await withTaskGroup(of: (project: Project, success: Bool).self) { group in
            var activeTasks = 0
            let maxConcurrentTasks = 1

            for project in projectsToPreload {
                while activeTasks >= maxConcurrentTasks {
                    if XcodePluginLog.verbose {
                        XcodePluginLog.logger.info("\(Self.t)预加载并发达到上限，等待一个任务完成")
                    }
                    _ = await group.next()
                    activeTasks -= 1
                }

                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(Self.t)添加预加载任务：\(project.name)")
                }
                group.addTask(priority: .background) {
                    let store = XcodeBuildServerStore(storageRootURL: AppConfig.getDBFolderURL())
                    let success = await EditorXcodeProjectPreloader.preloadProject(project, store: store)
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
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(Self.t)预加载任务完成：\(project.name)，success=\(success)")
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

}

private enum EditorXcodeProjectPreloader {
    private static let logPrefix = "🚀 "

    static func filterXcodeProjects(_ projects: [Project]) async -> [Project] {
        await Task.detached(priority: .utility) {
            projects.filter { project in
                let isXcodeProject = XcodeProjectResolver.isXcodeProjectRoot(URL(fileURLWithPath: project.path))
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(logPrefix)检查最近项目：\(project.name) -> isXcodeProject=\(isXcodeProject)")
                }
                return isXcodeProject
            }
        }.value
    }

    static func preloadProject(_ project: Project, store: XcodeBuildServerStore) async -> Bool {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(logPrefix)开始预加载项目：\(project.name)，path=\(project.path)")
        }
        guard let workspaceURL = await XcodeProjectBackgroundQuery.findWorkspace(in: project.path) else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.warning("\(logPrefix)预加载失败：未找到 workspace/xcodeproj，project=\(project.name)")
            }
            return false
        }

        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(logPrefix)找到 workspace：\(workspaceURL.path)")
        }

        if store.validate(forWorkspace: workspaceURL.path) != nil {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(logPrefix)buildServer 已存在且有效，跳过生成：\(workspaceURL.path)")
            }
            return true
        }

        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(logPrefix)buildServer 不存在或无效，开始后台生成：\(workspaceURL.path)")
        }
        return await Task.detached(priority: .background) {
            return await generateBuildServer(for: workspaceURL, projectName: project.name, store: store)
        }.value
    }

    private static func generateBuildServer(for workspaceURL: URL, projectName: String, store: XcodeBuildServerStore) async -> Bool {
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(logPrefix)开始生成 buildServer：project=\(projectName)，workspace=\(workspaceURL.path)")
        }

        let xcodeBuildServerPaths = [
            "/opt/homebrew/bin/xcode-build-server",
            "/usr/local/bin/xcode-build-server",
        ]

        var xcodeBuildServerPath: String?
        for path in xcodeBuildServerPaths {
            if FileManager.default.fileExists(atPath: path) {
                xcodeBuildServerPath = path
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(logPrefix)找到 xcode-build-server：\(path)")
                }
                break
            }
        }

        if xcodeBuildServerPath == nil {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(logPrefix)默认路径未找到 xcode-build-server，尝试 which")
            }
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
                    if XcodePluginLog.verbose {
                        XcodePluginLog.logger.info("\(logPrefix)which 找到 xcode-build-server：\(path)")
                    }
                } else if XcodePluginLog.verbose {
                    XcodePluginLog.logger.warning("\(logPrefix)which xcode-build-server 未找到，terminationStatus=\(process.terminationStatus)")
                }
            } catch {
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.error("\(logPrefix)执行 which xcode-build-server 失败：\(error.localizedDescription)")
                }
            }
        }

        guard let serverPath = xcodeBuildServerPath else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.warning("\(logPrefix)生成 buildServer 失败：找不到 xcode-build-server")
            }
            return false
        }

        let schemes = await fetchAvailableSchemes(for: workspaceURL)
        guard let scheme = schemes.first else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.warning("\(logPrefix)生成 buildServer 失败：未找到可用 scheme，workspace=\(workspaceURL.path)")
            }
            return false
        }

        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(logPrefix)使用 scheme 生成 buildServer：\(scheme)，schemesCount=\(schemes.count)")
        }

        let outputDirectory = store.ensureDirectory(forWorkspace: workspaceURL.path)

        let isProject = workspaceURL.pathExtension == "xcodeproj"
        let workspaceArg = isProject ? "-project" : "-workspace"
        let args = ["config", workspaceArg, workspaceURL.path, "-scheme", scheme]

        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(logPrefix)执行 xcode-build-server：\(serverPath) \(args.joined(separator: " "))，cwd=\(outputDirectory.path)")
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(filePath: serverPath)
            process.arguments = args
            process.currentDirectoryURL = outputDirectory
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { _ in
                let success = process.terminationStatus == 0
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(logPrefix)xcode-build-server 结束，success=\(success)，terminationStatus=\(process.terminationStatus)")
                }
                continuation.resume(returning: success)
            }

            do {
                try process.run()
            } catch {
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.error("\(logPrefix)xcode-build-server 启动失败：\(error.localizedDescription)")
                }
                continuation.resume(returning: false)
            }
        }
    }

    private static func fetchAvailableSchemes(for workspaceURL: URL) async -> [String] {
        var args = ["-list", "-json"]
        let isProject = workspaceURL.pathExtension == "xcodeproj"
        let workspaceArg = isProject ? "-project" : "-workspace"
        args += [workspaceArg, workspaceURL.path]
        
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(logPrefix)开始获取 schemes：xcodebuild \(args.joined(separator: " "))")
        }
        
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
                    if XcodePluginLog.verbose {
                        XcodePluginLog.logger.warning("\(logPrefix)xcodebuild 获取 schemes 失败，terminationStatus=\(process.terminationStatus)")
                    }
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
                
                let uniqueSchemes = Array(Set(schemes))
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.info("\(logPrefix)xcodebuild 获取 schemes 完成，count=\(uniqueSchemes.count)，schemes=\(uniqueSchemes.joined(separator: ", "))")
                }
                continuation.resume(returning: uniqueSchemes)
            }
            
            do {
                try process.run()
            } catch {
                if XcodePluginLog.verbose {
                    XcodePluginLog.logger.error("\(logPrefix)xcodebuild 启动失败：\(error.localizedDescription)")
                }
                continuation.resume(returning: [])
            }
        }
    }
}

#Preview("RootView Wrapper") {
    EditorXcodePluginRootView(content: Text("Content View").padding())
}
