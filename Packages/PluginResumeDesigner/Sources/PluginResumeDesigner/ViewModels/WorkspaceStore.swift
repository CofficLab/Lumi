import Foundation
import KitResume

/// 简历工作区：应用数据目录（app 存储）下的简历列表与选中状态。
@MainActor
final class WorkspaceStore: ObservableObject {
    static let shared = WorkspaceStore()

    /// APP 内（应用数据目录）简历列表。简历文档只存储在应用数据目录，不支持项目内存储。
    @Published private(set) var appResumes: [ResumeDocument] = []

    @Published private(set) var selectedResume: ResumeResolvedDocument?
    @Published var selectedResumeID: String?
    @Published var lastError: String?
    @Published var lastExportURL: URL?

    let documentStore = ResumeDocumentStore()

    /// APP 内存储根目录。
    private(set) var appStorageDirectory: URL?

    private init() {}

    // MARK: - Paths

    /// APP 内存储路径字符串。
    var appStoragePath: String { appStorageDirectory?.path ?? "" }

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

    // MARK: - Reload

    /// 重新加载简历列表以及当前选中简历。
    func reload() {
        lastError = nil
        reloadApp()
        refreshSelectedResume()
    }

    /// 当数据发生变化时调用，按需刷新列表与选中。
    func reload(selectResume resumeID: String? = nil) {
        lastError = nil
        reloadApp()
        if let resumeID {
            selectedResumeID = resumeID
            refreshSelectedResume()
            return
        }
        refreshSelectedResume()
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
              let document = appResumes.first(where: { $0.id == selectedResumeID }) else {
            selectedResume = nil
            return
        }
        do {
            selectedResume = try documentStore.readResume(
                storagePath: appStoragePath,
                slug: document.id
            )
        } catch {
            selectedResume = nil
        }
    }

    // MARK: - Selection

    func select(resumeID: String) {
        guard appResumes.contains(where: { $0.id == resumeID }) else {
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
            try documentStore.deleteResume(storagePath: appStoragePath, slug: id)
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
