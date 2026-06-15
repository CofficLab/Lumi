import LumiCoreKit
import os
import SuperLogKit
import SwiftUI
import XcodeKit

/// Xcode 插件根视图包裹器
@MainActor
public struct EditorSwiftPluginRootView<Content: View>: View, SuperLog {
    public nonisolated static var emoji: String { "🚀" }

    public let content: Content

    @EnvironmentObject var projectVM: WindowProjectVM
    @EnvironmentObject var recentProjectsVM: AppProjectsVM

    @State private var hasTriggeredPreload = false
    @State private var preloadStatus: PreloadStatus = .idle

    enum PreloadStatus: Sendable {
        case idle
        case loading(count: Int)
        case completed(success: Int, failed: Int)
    }

    public var body: some View {
        content
            .onAppear {
                if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                        SwiftPluginLog.logger.info("\(Self.t)RootView onAppear")
                    }
                }
                guard !hasTriggeredPreload else {
                    if SwiftPluginLog.verbose {
                        if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t)预加载已触发过，跳过")
                        }
                    }
                    return
                }
                hasTriggeredPreload = true
                if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                        SwiftPluginLog.logger.info("\(Self.t)准备延迟 3 秒后预加载最近 Xcode 项目")
                    }
                }
                Task {
                    try? await Task.sleep(nanoseconds: 3000000000)
                    await preloadRecentXcodeProjects()
                }
            }
    }

    // MARK: - 预加载逻辑

    private func preloadRecentXcodeProjects() async {
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(Self.t)开始扫描最近项目用于 Xcode 预加载")
            }
        }
        let recentProjects = recentProjectsVM.getRecentProjects()
        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(Self.t)最近项目数量：\(recentProjects.count)")
            }
        }
        let xcodeProjects = await EditorXcodeProjectPreloader.filterXcodeProjects(recentProjects)

        guard !xcodeProjects.isEmpty else {
            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(Self.t)没有找到最近的 Xcode 项目，跳过预加载")
                }
            }
            return
        }

        let projectsToPreload = Array(xcodeProjects.prefix(3))

        if SwiftPluginLog.verbose {
            if SwiftPluginLog.verbose {
                SwiftPluginLog.logger.info("\(Self.t)开始预加载 \(projectsToPreload.count) 个最近的 Xcode 项目：\(projectsToPreload.map(\.name).joined(separator: ", "))")
            }
        }

        await MainActor.run {
            self.preloadStatus = .loading(count: projectsToPreload.count)
        }

        await withTaskGroup(of: (project: Project, success: Bool).self) { group in
            var activeTasks = 0
            let maxConcurrentTasks = 1

            for project in projectsToPreload {
                while activeTasks >= maxConcurrentTasks {
                    if SwiftPluginLog.verbose {
                        if SwiftPluginLog.verbose {
                            SwiftPluginLog.logger.info("\(Self.t)预加载并发达到上限，等待一个任务完成")
                        }
                    }
                    _ = await group.next()
                    activeTasks -= 1
                }

                if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                        SwiftPluginLog.logger.info("\(Self.t)添加预加载任务：\(project.name)")
                    }
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
                if SwiftPluginLog.verbose {
                    if SwiftPluginLog.verbose {
                        SwiftPluginLog.logger.info("\(Self.t)预加载任务完成：\(project.name)，success=\(success)")
                    }
                }
            }

            await MainActor.run {
                self.preloadStatus = .completed(success: successCount, failed: failedCount)
            }

            if SwiftPluginLog.verbose {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(Self.t)预加载完成：\(successCount) 成功，\(failedCount) 失败")
                }
            }
        }
    }
}


#Preview("RootView Wrapper") {
    EditorSwiftPluginRootView(content: Text(verbatim: LumiPluginLocalization.string("Content View", bundle: .module)).padding())
}
