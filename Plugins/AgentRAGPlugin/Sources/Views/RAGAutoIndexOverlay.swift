import SuperLogKit
import SwiftUI
import LumiCoreKit
import ProjectsPlugin

/// RAG 自动索引覆盖层
///
/// 在应用启动和项目切换时，自动在后台确保 RAG 索引存在。
public struct RAGAutoIndexOverlay<Content: View>: View, SuperLog {
    public nonisolated static var emoji: String { "🦞" }
    // 泛型类型不支持 static stored property，这里用计算属性
    public nonisolated static var verbose: Bool { false }
    @State private var autoEnsureTask: Task<Void, Never>?
    @State private var lastAutoEnsureKey = ""

    public let content: Content

    public init(content: Content) {
        self.content = content
    }

    public var body: some View {
        ZStack {
            content
        }
        .onAppear {
            triggerAutoEnsureIndexForRecentProjects(source: "onAppear")
        }
        .onDisappear {
            autoEnsureTask?.cancel()
            autoEnsureTask = nil
        }
        .onChange(of: RAGPluginRuntime.currentProjectPath) { _, _ in
            triggerAutoEnsureIndexForRecentProjects(source: "projectChanged")
        }
    }
}

extension RAGAutoIndexOverlay {
    private func triggerAutoEnsureIndexForRecentProjects(source: String) {
        let currentPath = RAGPluginRuntime.currentProjectPath
        autoEnsureTask?.cancel()

        autoEnsureTask = Task { [currentPath] in
            let candidatePaths = await Task.detached(priority: .utility) {
                let recentPaths = await MainActor.run {
                    ProjectsPlugin.sharedStore.projects.map(\.path)
                }
                return Self.uniqueNonEmptyPaths([currentPath] + recentPaths)
                    .filter { Self.isExistingDirectory(path: $0) }
            }.value

            guard !Task.isCancelled, !candidatePaths.isEmpty else { return }

            let candidateKey = candidatePaths.joined(separator: "\n")
            let shouldTrigger = await MainActor.run {
                guard lastAutoEnsureKey != candidateKey else { return false }
                lastAutoEnsureKey = candidateKey
                return true
            }
            guard shouldTrigger else { return }

            let service = RAGPlugin.getService()
            // 服务已在 onEnable 时初始化，无需再次初始化
            for path in candidatePaths {
                guard !Task.isCancelled else { return }
                await service.ensureIndexedBackground(projectPath: path)
            }
            if RAGPlugin.verbose {
                RAGPlugin.logger.info("\(Self.t)批量自动索引已触发 source=\(source) count=\(candidatePaths.count)")
            }
        }
    }

    nonisolated private static func uniqueNonEmptyPaths(_ paths: [String]) -> [String] {
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

    nonisolated private static func isExistingDirectory(path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

#Preview("RAG Auto Index Overlay") {
    RAGAutoIndexOverlay(content: Text(verbatim: LumiPluginLocalization.string("Content", bundle: .module)))
}
