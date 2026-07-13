import AppKit
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

    @Environment(\.lumiCore) private var lumiCore
    @State private var hasTriggeredPreload = false
    @State private var preloadStatus: PreloadStatus = .idle
    @StateObject private var windowScope = EditorSwiftWindowScope()

    private var currentProjectPath: String {
        lumiCore?.projectState?.currentProject?.path ?? ""
    }

    private var projects: [LumiProjectEntry] {
        lumiCore?.projectState?.projects ?? []
    }

    enum PreloadStatus: Sendable {
        case idle
        case loading(count: Int)
        case completed(success: Int, failed: Int)
    }

    public var body: some View {
        content
            .environmentObject(windowScope.statusBarViewModel)
            .background {
                WindowScopeRegistration(scope: windowScope)
            }
            .overlay(alignment: .bottomTrailing) {
                preloadStatusView
            }
            .onAppear {
                if SwiftPluginLog.verbose {
                    SwiftPluginLog.logger.info("\(Self.t)RootView onAppear")
                }
                guard !hasTriggeredPreload else {
                    SwiftPluginLog.logger.info("\(Self.t)预加载已触发过，跳过")
                    return
                }
                hasTriggeredPreload = true
                SwiftPluginLog.logger.info("\(Self.t)准备延迟 3 秒后预加载最近 Xcode 项目")
                Task {
                    try? await Task.sleep(nanoseconds: 3000000000)
                    await preloadRecentXcodeProjects()
                }
            }
    }

    // MARK: - 预加载逻辑

    private func preloadRecentXcodeProjects() async {
        SwiftPluginLog.logger.info("\(Self.t)开始扫描最近项目用于 Xcode 预加载")
        let recentProjects = projects
        SwiftPluginLog.logger.info("\(Self.t)最近项目数量：\(recentProjects.count)")
        let xcodeProjects = await EditorXcodeProjectPreloader.filterXcodeProjects(recentProjects)

        guard !xcodeProjects.isEmpty else {
            SwiftPluginLog.logger.info("\(Self.t)没有找到最近的 Xcode 项目，跳过预加载")
            return
        }

        let projectsToPreload = Array(xcodeProjects.prefix(3))

        SwiftPluginLog.logger.info("\(Self.t)开始预加载 \(projectsToPreload.count) 个最近的 Xcode 项目：\(projectsToPreload.map(\.name).joined(separator: ", "))")

        await MainActor.run {
            self.preloadStatus = .loading(count: projectsToPreload.count)
        }

        await withTaskGroup(of: (project: LumiProjectEntry, success: Bool).self) { group in
            var activeTasks = 0
            let maxConcurrentTasks = 1

            for project in projectsToPreload {
                while activeTasks >= maxConcurrentTasks {
                    SwiftPluginLog.logger.info("\(Self.t)预加载并发达到上限，等待一个任务完成")
                    _ = await group.next()
                    activeTasks -= 1
                }

                SwiftPluginLog.logger.info("\(Self.t)添加预加载任务：\(project.name)")
                group.addTask(priority: .background) {
                    let store = EditorSwiftBuildServerStore.makeStore()
                    let activePath = await MainActor.run {
                        XcodeProjectContextBridge.shared.activeProjectPath
                    }
                    guard await MainActor.run(body: {
                        SemanticIndexPreloadCoordinator.shouldContinuePreloading(
                            activeProjectPath: activePath,
                            projectPath: project.path
                        )
                    }) else {
                        return (project, false)
                    }
                    let success = await EditorXcodeProjectPreloader.preloadProject(
                        project,
                        store: store,
                        activeProjectPath: activePath
                    )
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
                SwiftPluginLog.logger.info("\(Self.t)预加载任务完成：\(project.name)，success=\(success)")
            }

            await MainActor.run {
                self.preloadStatus = .completed(success: successCount, failed: failedCount)
            }

            SwiftPluginLog.logger.info("\(Self.t)预加载完成：\(successCount) 成功，\(failedCount) 失败")
        }
    }

    @ViewBuilder
    private var preloadStatusView: some View {
        switch preloadStatus {
        case .idle:
            EmptyView()
        case .loading(let count):
            Text(LumiPluginLocalization.string("Prewarming \(count) Xcode projects…", bundle: .module))
                .font(.caption2)
                .padding(6)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(8)
        case .completed(let success, let failed):
            Text(LumiPluginLocalization.string("Prewarm done: \(success) ok, \(failed) failed", bundle: .module))
                .font(.caption2)
                .padding(6)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(8)
        }
    }
}

private struct WindowScopeRegistration: NSViewRepresentable {
    let scope: EditorSwiftWindowScope

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                EditorSwiftWindowScopeRegistry.register(scope, forWindowNumber: window.windowNumber)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            EditorSwiftWindowScopeRegistry.register(scope, forWindowNumber: window.windowNumber)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        if let window = nsView.window {
            EditorSwiftWindowScopeRegistry.unregister(windowNumber: window.windowNumber)
        }
    }
}


#Preview("RootView Wrapper") {
    EditorSwiftPluginRootView(content: Text(verbatim: LumiPluginLocalization.string("Content View", bundle: .module)).padding())
}
