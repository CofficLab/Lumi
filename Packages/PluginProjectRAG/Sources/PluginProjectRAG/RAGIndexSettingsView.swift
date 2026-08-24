import ProjectRAGPlugin
import ProviderProject
import SwiftUI

/// V2 设置入口：保留旧版项目详情中的索引状态与手动控制能力。
@MainActor
struct RAGIndexSettingsView: View {
    let service: RAGService
    let projects: any ProjectProviding

    @State private var paused = false
    @State private var statuses: [String: RAGIndexStatus] = [:]

    var body: some View {
        Form {
            Section("Code Index") {
                Toggle("Pause background indexing", isOn: $paused)
                    .onChange(of: paused) { _, value in
                        Task { await service.setIndexingPaused(value) }
                    }
                Text("Semantic code search keeps the existing RAG database and indexes projects while you are idle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Projects") {
                if projects.projects.isEmpty {
                    Text("No projects available.").foregroundStyle(.secondary)
                }
                ForEach(projects.projects, id: \.path) { project in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(project.name)
                            Text(project.path).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(statusText(for: project.path)).font(.caption).foregroundStyle(.secondary)
                        Button("Rebuild") { Task { await service.ensureIndexedBackground(projectPath: project.path, force: true); await refresh() } }
                    }
                }
            }
        }
        .task { await refresh() }
    }

    private func statusText(for path: String) -> String {
        guard let status = statuses[path] else { return "Not indexed" }
        return status.isStale ? "Outdated" : "Up to date"
    }

    private func refresh() async {
        paused = await service.isIndexingPaused()
        var result: [String: RAGIndexStatus] = [:]
        for project in projects.projects {
            if let status = try? await service.getIndexStatus(projectPath: project.path) { result[project.path] = status }
        }
        statuses = result
    }
}
