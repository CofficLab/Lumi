import Foundation
import KitResume

/// 简历工作区：当前项目目录下的简历列表与选中状态。
@MainActor
final class WorkspaceStore: ObservableObject {
    static let shared = WorkspaceStore()

    /// 当前项目 `.lumi/resume-designer` 下的简历列表。
    @Published private(set) var projectResumes: [ResumeDocument] = []

    @Published private(set) var selectedResume: ResumeResolvedDocument?
    @Published var selectedResumeID: String?
    @Published var lastError: String?
    @Published var lastExportURL: URL?

    let documentStore = ResumeDocumentStore()

    /// 当前项目内存储根目录。
    private(set) var projectStorageDirectory: URL?
    private(set) var currentProjectPath: String?

    private init() {}

    // MARK: - Paths

    /// 项目内存储路径字符串。
    var projectStoragePath: String { projectStorageDirectory?.path ?? "" }

    // MARK: - Configuration

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

    // MARK: - Reload

    /// 重新加载简历列表以及当前选中简历。
    func reload() {
        lastError = nil
        reloadProject()
        refreshSelectedResume()
    }

    /// 当数据发生变化时调用，按需刷新列表与选中。
    func reload(selectResume resumeID: String? = nil) {
        lastError = nil
        reloadProject()
        if let resumeID {
            selectedResumeID = resumeID
            refreshSelectedResume()
            return
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

    private func refreshSelectedResume() {
        guard let selectedResumeID,
              let document = projectResumes.first(where: { $0.id == selectedResumeID }) else {
            selectedResume = nil
            return
        }
        do {
            selectedResume = try documentStore.readResume(
                storagePath: projectStoragePath,
                slug: document.id
            )
        } catch {
            selectedResume = nil
        }
    }

    // MARK: - Selection

    func select(resumeID: String) {
        guard projectResumes.contains(where: { $0.id == resumeID }) else {
            // 未找到：仅记录 ID。
            selectedResumeID = resumeID
            refreshSelectedResume()
            return
        }
        selectedResumeID = resumeID
        refreshSelectedResume()
    }

    // MARK: - Mutations

    func deleteResume(id: String) {
        do {
            try documentStore.deleteResume(storagePath: projectStoragePath, slug: id)
            if selectedResumeID == id {
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
