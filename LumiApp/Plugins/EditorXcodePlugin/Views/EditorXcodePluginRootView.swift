import SwiftUI
import os
import MagicKit

/// Xcode 插件预加载器的日志和配置辅助
/// 使用独立 enum 避免泛型类型中不支持 static stored properties 的问题
private enum XcodePluginLog {
    static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.preloader")
    nonisolated(unsafe) static var verbose: Bool = true
}

/// Xcode 插件根视图包裹器
///
/// 功能：
/// 1. 在应用启动时预加载最近 Xcode 项目的 buildServer.json
/// 2. 减少首次打开 Xcode 项目时的等待时间
/// 3. 在后台静默执行，不影响用户体验
@MainActor
struct EditorXcodePluginRootView<Content: View>: View {
    /// 日志标识 emoji
    static var emoji: String { "🚀" }

    /// 日志前缀（复用 SuperLog 的格式）
    static var t: String {
        let qosDesc = Thread.currentQosDescription
        let name = "EditorXcodePluginRootView"
        return "\(qosDesc) | \(emoji) \(name.padding(toLength: 27, withPad: " ", startingAt: 0)) | "
    }

    let content: Content

    @EnvironmentObject var projectVM: ProjectVM

    /// 标记是否已经触发过预加载
    @State private var hasTriggeredPreload = false

    /// 预加载状态
    @State private var preloadStatus: PreloadStatus = .idle

    /// 预加载状态枚举
    enum PreloadStatus: Sendable {
        case idle
        case loading(count: Int)
        case completed(success: Int, failed: Int)

        var displayDescription: String {
            switch self {
            case .idle:
                return String(localized: "Not Started", table: "EditorXcodePlugin")
            case .loading(let count):
                let format = String(localized: "Preloading %lld project(s)...", table: "EditorXcodePlugin")
                return String(format: format, count)
            case .completed(let success, let failed):
                if failed == 0 {
                    let format = String(localized: "Preload completed: %lld succeeded", table: "EditorXcodePlugin")
                    return String(format: format, success)
                } else {
                    let format = String(localized: "Preload completed: %lld succeeded, %lld failed", table: "EditorXcodePlugin")
                    return String(format: format, success, failed)
                }
            }
        }
    }

    var body: some View {
        content
            .onAppear {
                guard !hasTriggeredPreload else { return }
                hasTriggeredPreload = true

                // 延迟 1 秒后开始预加载，避免影响应用启动性能
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 秒
                    await preloadRecentXcodeProjects()
                }
            }
    }

    // MARK: - 预加载逻辑

    /// 预加载最近 Xcode 项目的 buildServer.json
    private func preloadRecentXcodeProjects() async {
        let recentProjects = projectVM.getRecentProjects()

        // 筛选出 Xcode 项目
        let xcodeProjects = recentProjects.filter { project in
            XcodeProjectResolver.isXcodeProjectRoot(URL(filePath: project.path))
        }

        guard !xcodeProjects.isEmpty else {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(Self.t)📁 没有找到最近的 Xcode 项目，跳过预加载")
            }
            return
        }

        // 限制预加载数量（最多 3 个，避免过度消耗资源）
        let projectsToPreload = Array(xcodeProjects.prefix(3))

        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("\(Self.t)🚀 开始预加载 \(projectsToPreload.count) 个最近的 Xcode 项目")
            for project in projectsToPreload {
                XcodePluginLog.logger.debug("\(Self.t)  - \(project.name) @ \(project.path)")
            }
        }

        await MainActor.run {
            self.preloadStatus = .loading(count: projectsToPreload.count)
        }

        // 使用 TaskGroup 并发预加载（最多 2 个并发）
        await withTaskGroup(of: (project: Project, success: Bool).self) { group in
            var activeTasks = 0
            let maxConcurrentTasks = 2

            for project in projectsToPreload {
                // 控制并发数量
                while activeTasks >= maxConcurrentTasks {
                    _ = await group.next()
                    activeTasks -= 1
                }

                group.addTask {
                    let success = await Self.preloadProject(project)
                    return (project, success)
                }
                activeTasks += 1
            }

            // 收集结果
            var successCount = 0
            var failedCount = 0

            for await (project, success) in group {
                if success {
                    successCount += 1
                    if XcodePluginLog.verbose {
                        XcodePluginLog.logger.info("\(Self.t)✅ 预加载成功：\(project.name)")
                    }
                } else {
                    failedCount += 1
                    if XcodePluginLog.verbose {
                        XcodePluginLog.logger.warning("\(Self.t)⚠️ 预加载失败：\(project.name)")
                    }
                }
            }

            await MainActor.run {
                self.preloadStatus = .completed(success: successCount, failed: failedCount)
            }

            if XcodePluginLog.verbose {
                XcodePluginLog.logger.info("\(Self.t)🎉 预加载完成：成功 \(successCount) 个，失败 \(failedCount) 个")
            }
        }
    }

    // MARK: - 单个项目预加载

    /// 预加载单个项目的 buildServer.json
    private static func preloadProject(_ project: Project) async -> Bool {
        let projectURL = URL(filePath: project.path)

        // 查找 workspace
        guard let workspaceURL = XcodeProjectResolver.findWorkspace(in: projectURL) else {
            XcodePluginLog.logger.warning("\(Self.t)⚠️ 未找到 workspace：\(project.name)")
            return false
        }

        // 检查是否已有有效的 buildServer.json
        if XcodeBuildServerStore.validate(forWorkspace: workspaceURL.path) != nil {
            if XcodePluginLog.verbose {
                XcodePluginLog.logger.debug("\(Self.t)✓ \(project.name) 已有有效配置，跳过生成")
            }
            return true
        }

        // 生成 buildServer.json
        if XcodePluginLog.verbose {
            XcodePluginLog.logger.debug("\(Self.t)⏳ 正在为 \(project.name) 生成 buildServer.json...")
        }

        // 使用后台优先级，避免影响主线程性能
        let success = await Task.detached(priority: .background) {
            return await generateBuildServer(for: workspaceURL, projectName: project.name)
        }.value

        return success
    }

    /// 为指定的 workspace 生成 buildServer.json
    private static func generateBuildServer(for workspaceURL: URL, projectName: String) async -> Bool {
        // 检查 xcode-build-server 是否安装
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

        // 尝试从 PATH 中查找
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
            } catch {
                // 忽略错误
            }
        }

        guard let serverPath = xcodeBuildServerPath else {
            XcodePluginLog.logger.warning("\(Self.t)⚠️ 未安装 xcode-build-server，无法预加载")
            return false
        }

        // 首先获取可用的 scheme 列表
        let schemes = await fetchAvailableSchemes(for: workspaceURL)
        guard let scheme = schemes.first else {
            XcodePluginLog.logger.warning("\(Self.t)⚠️ 未找到可用的 scheme")
            return false
        }

        // 确保输出目录存在
        let outputDirectory = XcodeBuildServerStore.ensureDirectory(forWorkspace: workspaceURL.path)

        // 准备命令参数
        let isProject = workspaceURL.pathExtension == "xcodeproj"
        let workspaceArg = isProject ? "-project" : "-workspace"
        let args = ["config", workspaceArg, workspaceURL.path, "-scheme", scheme]

        // 执行命令
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
                XcodePluginLog.logger.error("\(Self.t)❌ 命令执行失败：\(error.localizedDescription)")
                continuation.resume(returning: false)
            }
        }
    }

    /// 获取可用的 scheme 列表
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
                XcodePluginLog.logger.error("\(Self.t)❌ 获取 scheme 列表失败：\(error.localizedDescription)")
                continuation.resume(returning: [])
            }
        }
    }
}

// MARK: - Preview

#Preview("RootView Wrapper") {
    EditorXcodePluginRootView(content: Text("Content View").padding())
}
