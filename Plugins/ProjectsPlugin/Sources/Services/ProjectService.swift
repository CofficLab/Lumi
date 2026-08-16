import Foundation
import KernelLumi

/// 项目服务实现
///
/// 在内存中维护「当前项目」的打开文件列表（`openFileURLs` / `currentFileURL`），
/// 并按项目路径持久化到磁盘，下次打开 App 时恢复到内存。
@MainActor
public final class ProjectService: ProjectProviding {

    // MARK: - Published State

    @Published public private(set) var currentProject: ProjectInfo?
    @Published public private(set) var openFileURLs: [URL] = []
    @Published public private(set) var currentFileURL: URL?
    @Published public private(set) var projects: [ProjectInfo] = []

    // MARK: - 持久化

    /// 用于按项目持久化打开文件记录；为 nil 时仅保留内存状态。
    private let store: ProjectsStore?

    /// 所有项目打开过的文件记录，key 为标准化后的项目路径。
    private var openedFilesByProject: [String: ProjectOpenedFiles]

    /// 防抖保存任务。
    private var saveTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(store: ProjectsStore? = nil) {
        self.store = store
        self.openedFilesByProject = store?.loadOpenedFiles() ?? [:]

        let savedProjects = store?.loadProjects() ?? []
        self.projects = savedProjects.map {
            ProjectInfo(name: $0.name, path: ProjectsStore.normalizedPath($0.path), language: $0.language)
        }

        if let current = store?.loadCurrentProject(from: savedProjects) {
            self.currentProject = ProjectInfo(
                name: current.name,
                path: ProjectsStore.normalizedPath(current.path),
                language: current.language
            )
        } else {
            self.currentProject = nil
        }
    }

    // MARK: - ProjectProviding

    public func openProject(at path: String) async throws {
        let key = ProjectsStore.normalizedPath(path)
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        let project = ProjectInfo(name: name, path: key)
        currentProject = project

        // 从磁盘恢复该项目的打开文件记录（无记录则重置为空）。
        if let entry = openedFilesByProject[key] {
            openFileURLs = entry.openFileURLs
            currentFileURL = entry.currentFileURL
        } else {
            openFileURLs = []
            currentFileURL = nil
        }

        // 如果不在列表中，添加到列表
        if !projects.contains(where: { $0.path == key }) {
            projects.append(project)
        }
    }

    public func synchronizeProjects(_ projects: [ProjectInfo]) {
        var seen = Set<String>()
        self.projects = projects.compactMap { project in
            let path = ProjectsStore.normalizedPath(project.path)
            guard !path.isEmpty, seen.insert(path).inserted else { return nil }
            return ProjectInfo(name: project.name, path: path, language: project.language)
        }

        if let currentProject,
           !self.projects.contains(where: { $0.path == currentProject.path }) {
            self.currentProject = self.projects.first
        }
    }

    /// - Deprecated: Phase 3（编辑器重构 §4.3/§20）：当前文件的唯一事实源是
    ///   Editor（`kernel.editorV2`）。Project 侧不再维护打开文件状态；
    ///   该 API 仅为兼容保留，持久化的打开文件记录不再被任何 UI 读取。
    @available(*, deprecated, message: "使用 kernel.editorV2.documents / sessions（Editor 单一事实源）")
    public func updateCurrentFile(_ fileURL: URL?) {
        let standardizedURL = fileURL?.standardizedFileURL
        currentFileURL = standardizedURL
        guard let standardizedURL else { return }
        updateOpenFiles(openFileURLs + [standardizedURL])
    }

    @available(*, deprecated, message: "使用 kernel.editorV2.documents / sessions（Editor 单一事实源）")
    public func updateOpenFiles(_ fileURLs: [URL]) {
        var uniqueURLs: [URL] = []
        uniqueURLs.reserveCapacity(fileURLs.count)

        for fileURL in fileURLs {
            let standardizedURL = fileURL.standardizedFileURL
            if !uniqueURLs.contains(standardizedURL) {
                uniqueURLs.append(standardizedURL)
            }
        }

        openFileURLs = uniqueURLs
        persistCurrentProject()
    }

    @available(*, deprecated, message: "使用 kernel.editorV2.sessions.close（Editor 单一事实源）")
    public func closeFile(_ fileURL: URL) {
        let standardizedURL = fileURL.standardizedFileURL

        // 记录被关闭文件在列表中的位置，用于选择下一个激活文件
        let closedIndex = openFileURLs.firstIndex(of: standardizedURL)
        openFileURLs.removeAll { $0 == standardizedURL }

        // 如果关闭的是当前文件，激活相邻文件；否则保持不变
        if currentFileURL == standardizedURL {
            if !openFileURLs.isEmpty, let closedIndex {
                // 优先选同位置的；如果已越界则取最后一个
                let nextIndex = min(closedIndex, openFileURLs.count - 1)
                currentFileURL = openFileURLs[nextIndex]
            } else {
                currentFileURL = nil
            }
        }

        persistCurrentProject()
    }

    public func closeProject() async {
        persistCurrentProject()
        currentProject = nil
        openFileURLs = []
        currentFileURL = nil
    }

    public func refreshProjects() async throws {
        // 简单实现：无操作
        // 完整实现会扫描最近项目目录
    }

    // MARK: - 持久化辅助

    /// 当前项目对应的持久化 key。
    private var currentProjectKey: String? {
        currentProject.map { ProjectsStore.normalizedPath($0.path) }
    }

    /// 将当前项目的打开文件记录写入内存字典，并触发防抖保存。
    private func persistCurrentProject() {
        guard let key = currentProjectKey else { return }
        openedFilesByProject[key] = ProjectOpenedFiles(
            openFileURLs: openFileURLs,
            currentFileURL: currentFileURL
        )
        scheduleSave()
    }

    /// 防抖保存：合并短时间内的多次更新，最多每 0.3s 落盘一次。
    private func scheduleSave() {
        guard let store else { return }
        let snapshot = openedFilesByProject
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            store.saveOpenedFiles(snapshot)
        }
    }
}
