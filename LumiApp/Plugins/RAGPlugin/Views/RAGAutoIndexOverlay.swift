import MagicKit
import SwiftUI

/// RAG 自动索引覆盖层
///
/// 在应用启动和项目切换时，自动在后台确保 RAG 索引存在。
struct RAGAutoIndexOverlay<Content: View>: View, SuperLog {
    nonisolated static var emoji: String { "🦞" }
    nonisolated static var verbose: Bool { false }

    @EnvironmentObject private var projectVM: ProjectVM

    let content: Content

    var body: some View {
        ZStack {
            content
        }
        .onAppear {
            triggerAutoEnsureIndex(for: projectVM.currentProjectPath, source: "onAppear")
        }
        .onChange(of: projectVM.currentProjectPath) { _, newPath in
            triggerAutoEnsureIndex(for: newPath, source: "projectChanged")
        }
    }
}

extension RAGAutoIndexOverlay {
    private func triggerAutoEnsureIndex(for projectPath: String, source: String) {
        let trimmedPath = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return }

        Task {
            let service = RAGPlugin.getService()
            do {
                try await service.initialize()
                let needsIndex = try await service.checkNeedsIndex(projectPath: trimmedPath)
                guard needsIndex else {
                    if RAGPlugin.verbose {
                        RAGPlugin.logger.info("\(Self.t)自动索引跳过（无需索引）source=\(source)")
                    }
                    return
                }

                RAGPlugin.logger.info("\(Self.t)自动触发后台索引 source=\(source) path=\(trimmedPath)")
                await service.ensureIndexedBackground(projectPath: trimmedPath)
            } catch {
                RAGPlugin.logger.error("\(Self.t)自动索引失败 source=\(source): \(error.localizedDescription)")
            }
        }
    }
}

#Preview("RAG Auto Index Overlay") {
    RAGAutoIndexOverlay(content: Text("Content"))
        .inRootView()
}
