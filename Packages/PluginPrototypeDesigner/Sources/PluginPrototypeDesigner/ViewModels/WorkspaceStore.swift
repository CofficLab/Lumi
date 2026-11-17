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
        // 不预建目录：底层 `PrototypeDocumentStore` 在真正写入时才会创建。
        // 否则项目一打开就会留下空的 `.lumi/prototype`，让用户困惑。
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
            // manifest 已随列表解码在内存里，直接复用，不再重复读盘（#1290）。
            selectedScreen = try documentStore.readScreen(
                project: project,
                storagePath: projectStoragePath,
                screenSlug: screenID
            )
            selectedScreenID = screenID
        } catch {
            selectedScreen = nil
        }
    }

    // MARK: - 选中

    func select(projectID: String, screenID: String?) {
        // 选中的仍是已加载的同一屏时不再重复读盘（#1290）。
        if selectedProjectID == projectID, selectedScreenID == screenID, selectedScreen != nil {
            return
        }
        selectedProjectID = projectID
        selectedScreenID = screenID
        // 选中不改变项目目录：只刷新选中屏幕，不重扫全部项目。
        // 原先这里无条件 reload()，每次点击轨道行都会在主线程枚举并解码
        // 整个存储目录的 manifest，再重复读取选中项目的 manifest 与 HTML（#1290）。
        refreshSelectedScreen()
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
