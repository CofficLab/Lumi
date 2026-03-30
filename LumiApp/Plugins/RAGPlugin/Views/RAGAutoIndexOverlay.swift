import MagicKit
import SwiftUI

/// RAG 自动索引覆盖层
///
/// 在应用启动和项目切换时，自动在后台确保 RAG 索引存在。
struct RAGAutoIndexOverlay<Content: View>: View, SuperLog {
    nonisolated static var emoji: String { "🦞" }
    nonisolated static var verbose: Bool { false }

    @EnvironmentObject private var projectVM: ProjectVM
    private let recentProjectsStore = RecentProjectsStore()

    let content: Content

    var body: some View {
        ZStack {
            content
        }
        .onAppear {
            triggerAutoEnsureIndexForRecentProjects(source: "onAppear")
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            triggerAutoEnsureIndexForRecentProjects(source: "projectChanged")
        }
    }
}

extension RAGAutoIndexOverlay {
    private func triggerAutoEnsureIndexForRecentProjects(source: String) {
        let recentPaths = recentProjectsStore.loadProjects().map(\.path)
        let currentPath = projectVM.currentProjectPath
        let candidatePaths = uniqueNonEmptyPaths([currentPath] + recentPaths)
        guard !candidatePaths.isEmpty else { return }

        Task {
            let service = RAGPlugin.getService()
            // 服务已在 onEnable 时初始化，无需再次初始化
            for path in candidatePaths {
                guard isExistingDirectory(path: path) else { continue }
                await service.ensureIndexedBackground(projectPath: path)
            }
            if Self.verbose {
                RAGPlugin.logger.info("\(Self.t)批量自动索引已触发 source=\(source) count=\(candidatePaths.count)")
            }
        }
    }

    private func uniqueNonEmptyPaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for rawPath in paths {
            let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let normalized = URL(fileURLWithPath: trimmed).standardizedFileURL.path
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(normalized)
        }
        return result
    }

    private func isExistingDirectory(path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

#Preview("RAG Auto Index Overlay") {
    RAGAutoIndexOverlay(content: Text("Content"))
        .inRootView()
}
