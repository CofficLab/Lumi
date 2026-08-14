import Foundation
import ResumeKit

@MainActor
final class WorkspaceStore: ObservableObject {
    static let shared = WorkspaceStore()

    /// 项目内（当前打开项目 `.lumi/resume-designer`）简历列表。
    @Published private(set) var projectResumes: [ResumeDocument] = []

    /// APP 内（应用数据目录）简历列表。
    @Published private(set) var appResumes: [ResumeDocument] = []

    @Published private(set) var selectedResume: ResumeResolvedDocument?
    @Published var selectedScope: Scope = .project
    @Published var selectedResumeID: String?
    @Published var lastError: String?
    @Published var lastExportURL: URL?

    let documentStore = ResumeDocumentStore()

    /// APP 内存储根目录。
    private(set) var appStorageDirectory: URL?
    /// 项目内存储根目录（基于当前项目路径；nil 表示无打开项目）。
    private(set) var projectStorageDirectory: URL?
    /// 当前打开项目的路径。
    private(set) var currentProjectPath: String?

    private init() {}

    // MARK: - Paths

    /// APP 内存储路径字符串。
    var appStoragePath: String { appStorageDirectory?.path ?? "" }

    /// 项目内存储路径字符串（无打开项目时为空）。
    var projectStoragePath: String { projectStorageDirectory?.path ?? "" }

    /// 指定 scope 的存储路径（用于工具路由）。
    func storagePath(for scope: Scope) -> String {
        switch scope {
        case .project: projectStoragePath
        case .app: appStoragePath
        }
    }

    /// 指定 scope 的简历列表（用于 UI）。
    func resumes(for scope: Scope) -> [ResumeDocument] {
        switch scope {
        case .project: projectResumes
        case .app: appResumes
        }
    }

    // MARK: - Configuration

    func setAppStorage(appStorageDirectory: URL?) {
        let resolved = appStorageDirectory?.standardizedFileURL
        guard self.appStorageDirectory != resolved else { return }
        self.appStorageDirectory = resolved
        if let resolved {
            try? FileManager.default.createDirectory(at: resolved, withIntermediateDirectories: true)
        }
        reload()
    }

    func setProjectStorage(projectPath: String?, projectStorageDirectory: URL?) {
        let resolvedPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPath = (resolvedPath?.isEmpty == false) ? resolvedPath : nil
        guard self.currentProjectPath != normalizedPath else { return }
        self.currentProjectPath = normalizedPath
        self.projectStorageDirectory = projectStorageDirectory?.standardizedFileURL
        if let projectStorageDirectory {
            try? FileManager.default.createDirectory(at: projectStorageDirectory, withIntermediateDirectories: true)
        }
        reload()
    }

    // MARK: - Reload

    /// 重新加载所有 scope 的简历列表以及当前选中简历。
    func reload() {
        lastError = nil
        reloadProject()
        reloadApp()
        refreshSelectedResume()
    }

    /// 当某个 scope 的数据发生变化时调用，按需刷新简历与选中。
    func reload(scope: Scope, selectResume resumeID: String? = nil) {
        lastError = nil
        switch scope {
        case .project:
            reloadProject()
            if let resumeID {
                selectedScope = .project
                selectedResumeID = resumeID
                refreshSelectedResume()
                return
            }
        case .app:
            reloadApp()
            if let resumeID {
                selectedScope = .app
                selectedResumeID = resumeID
                refreshSelectedResume()
                return
            }
        }
        refreshSelectedResume()
    }

    private func reloadProject() {
        guard !projectStoragePath.isEmpty else {
            projectResumes = []
            return
        }
        do {
            projectResumes = try documentStore.listResumes(storagePath: projectStoragePath)
        } catch {
            projectResumes = []
            lastError = error.localizedDescription
        }
    }

    private func reloadApp() {
        guard !appStoragePath.isEmpty else {
            appResumes = []
            return
        }
        do {
            appResumes = try documentStore.listResumes(storagePath: appStoragePath)
        } catch {
            appResumes = []
            lastError = error.localizedDescription
        }
    }

    private func refreshSelectedResume() {
        guard let selectedResumeID,
              let document = resumes(for: selectedScope).first(where: { $0.id == selectedResumeID }) else {
            selectedResume = nil
            return
        }
        do {
            selectedResume = try documentStore.readResume(
                storagePath: storagePath(for: selectedScope),
                slug: document.id
            )
        } catch {
            selectedResume = nil
        }
    }

    // MARK: - Selection

    func selectScope(_ scope: Scope, resumeID: String) {
        selectedScope = scope
        selectedResumeID = resumeID
        reload()
    }

    func select(resumeID: String) {
        if projectResumes.contains(where: { $0.id == resumeID }) {
            selectScope(.project, resumeID: resumeID)
            return
        }
        if appResumes.contains(where: { $0.id == resumeID }) {
            selectScope(.app, resumeID: resumeID)
            return
        }
        // 兜底：保持当前 scope，仅记录 ID。
        selectedResumeID = resumeID
        refreshSelectedResume()
    }

    // MARK: - Mutations

    func deleteResume(scope: Scope, id: String) {
        do {
            try documentStore.deleteResume(storagePath: storagePath(for: scope), slug: id)
            if selectedScope == scope, selectedResumeID == id {
                selectedResumeID = nil
                selectedResume = nil
            }
            reload()
        } catch {
            setError(error)
        }
    }

    func setError(_ error: Error) { lastError = error.localizedDescription }
}
