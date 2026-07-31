import Foundation
@testable import LumiKernel

/// 测试用 `ProjectProviding` 实现,带与真实实现一致的 current/open 文件去重语义。
@MainActor
final class MockProjectProviding: ProjectProviding {
    @Published var currentProject: ProjectInfo?
    @Published var openFileURLs: [URL] = []
    @Published var currentFileURL: URL?
    @Published var projects: [ProjectInfo] = []

    func openProject(at path: String) async throws {
        let url = URL(fileURLWithPath: path)
        currentProject = ProjectInfo(name: url.lastPathComponent, path: path)
        currentFileURL = nil
    }

    func updateCurrentFile(_ fileURL: URL?) {
        let standardizedURL = fileURL?.standardizedFileURL
        currentFileURL = standardizedURL
        guard let standardizedURL else { return }
        updateOpenFiles(openFileURLs + [standardizedURL])
    }

    func updateOpenFiles(_ fileURLs: [URL]) {
        var uniqueURLs: [URL] = []
        for fileURL in fileURLs {
            let standardizedURL = fileURL.standardizedFileURL
            if !uniqueURLs.contains(standardizedURL) {
                uniqueURLs.append(standardizedURL)
            }
        }
        openFileURLs = uniqueURLs
    }

    func closeProject() async {
        currentProject = nil
        openFileURLs = []
        currentFileURL = nil
    }

    func refreshProjects() async throws {}
}
