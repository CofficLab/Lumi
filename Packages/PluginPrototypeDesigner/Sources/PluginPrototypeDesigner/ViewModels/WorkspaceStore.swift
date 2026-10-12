import Foundation
import KitPrototype

/// 原型工作区：当前项目 `.lumi/prototype` 下的原型项目列表与选中状态。
@MainActor
final class WorkspaceStore: ObservableObject {
    static let shared = WorkspaceStore()

    /// 当前项目内的原型项目列表（按更新时间倒序）。
    @Published private(set) var projects: [PrototypeProject] = []

    /// 当前选中的屏幕（已解析出 HTML）。
    @Published private(set) var selectedScreen: PrototypeResolvedScreen?

    @Published var selectedProjectID: String?
    @Published var selectedScreenID: String?
    @Published var lastError: String?
    @Published var lastExportURL: URL?

    let documentStore = PrototypeDocumentStore()

    /// 项目内存储根目录（基于当前项目路径；nil 表示无打开项目）。
    private(set) var projectStorageDirectory: URL?
    /// 当前打开项目的路径。
    private(set) var currentProjectPath: String?

    private init() {}

    // MARK: - 路径

    /// 项目内存储路径字符串（无打开项目时为空）。
    var projectStoragePath: String { projectStorageDirectory?.path ?? "" }

    /// 当前选中的原型项目。
    var selectedProject: PrototypeProject? {
        guard let selectedProjectID else { return nil }
        return projects.first { $0.id == selectedProjectID }
    }

    // MARK: - 配置

    func setProjectStorage(projectPath: String?, projectStorageDirectory: URL?) {
        let normalizedPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = normalizedPath?.isEmpty == false ? normalizedPath : nil
        let resolved = projectStorageDirectory?.standardizedFileURL
        guard self.currentProjectPath != path || self.projectStorageDirectory != resolved else { return }
        self.currentProjectPath = path
        self.projectStorageDirectory = resolved
        if let resolved {
            try? FileManager.default.createDirectory(at: resolved, withIntermediateDirectories: true)
        }
        reload()
    }

    // MARK: - 重新加载

    /// 重新加载项目列表与当前选中屏幕。
    func reload() {
        lastError = nil
        reloadProjects()
        refreshSelectedScreen()
    }

    /// 数据变化后调用，按需刷新列表与选中。
    func reload(selectProject projectID: String? = nil, screen screenID: String? = nil) {
        lastError = nil
        reloadProjects()
        if let projectID {
            selectedProjectID = projectID
            selectedScreenID = screenID
        }
        refreshSelectedScreen()
    }

    private func reloadProjects() {
        guard !projectStoragePath.isEmpty else {
            projects = []
            return
        }
        do {
            projects = try documentStore.listProjects(storagePath: projectStoragePath)
        } catch {
            projects = []
            lastError = error.localizedDescription
        }
    }

    private func refreshSelectedScreen() {
        guard let selectedProjectID,
              let project = projects.first(where: { $0.id == selectedProjectID }),
              !project.screens.isEmpty else {
            selectedScreen = nil
            return
        }
        let screenID = selectedScreenID.flatMap { id in
            project.screen(id: id) != nil ? id : nil
        } ?? project.sortedScreens.first?.id
        guard let screenID else {
            selectedScreen = nil
            return
        }
        do {
            selectedScreen = try documentStore.readScreen(
                storagePath: projectStoragePath,
                projectSlug: selectedProjectID,
                screenSlug: screenID
            )
            selectedScreenID = screenID
        } catch {
            selectedScreen = nil
        }
    }

    // MARK: - 选中

    func select(projectID: String, screenID: String?) {
        selectedProjectID = projectID
        selectedScreenID = screenID
        reload()
    }

    // MARK: - 变更

    func deleteProject(id: String) {
        do {
            try documentStore.deleteProject(storagePath: projectStoragePath, projectSlug: id)
            if selectedProjectID == id {
                selectedProjectID = nil
                selectedScreenID = nil
                selectedScreen = nil
            }
            reload()
        } catch {
            setError(error)
        }
    }

    func deleteScreen(projectID: String, screenID: String) {
        do {
            try documentStore.deleteScreen(
                storagePath: projectStoragePath,
                projectSlug: projectID,
                screenSlug: screenID
            )
            if selectedProjectID == projectID, selectedScreenID == screenID {
                selectedScreenID = nil
            }
            reload(selectProject: projectID)
        } catch {
            setError(error)
        }
    }

    func setError(_ error: Error) { lastError = error.localizedDescription }
}
