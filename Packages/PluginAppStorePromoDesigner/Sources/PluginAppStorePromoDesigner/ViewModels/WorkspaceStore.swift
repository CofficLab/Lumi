import KitAppStorePromo
import Foundation

/// 旧版 `Scope` 的兼容别名：KernelCore 版本中定义在 `PromoDesignerRuntime` 中。
typealias Scope = PromoScope

@MainActor
final class WorkspaceStore: ObservableObject {
    static let shared = WorkspaceStore()

    /// 项目内（当前打开项目 `.lumi/app-store-promo`）任务列表。
    @Published private(set) var projectTasks: [AppStorePromoTask] = []

    /// APP 内（应用数据目录）任务列表。
    @Published private(set) var appTasks: [AppStorePromoTask] = []

    @Published private(set) var selectedImage: AppStorePromoResolvedImage?
    @Published var selectedScope: Scope = .project
    @Published var selectedTaskID: String?
    @Published var selectedImageID: String?
    @Published var selectedLocaleIdentifier: String?
    @Published var selectedDisplayType = "APP_IPHONE_67"
    @Published var lastError: String?
    @Published var lastExportURL: URL?

    let documentStore = AppStorePromoDocumentStore()

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

    /// 指定 scope 的任务列表（用于 UI）。
    func tasks(for scope: Scope) -> [AppStorePromoTask] {
        switch scope {
        case .project: projectTasks
        case .app: appTasks
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

    /// 重新加载所有 scope 的任务列表以及当前选中图像。
    func reload() {
        lastError = nil
        reloadProject()
        reloadApp()
        refreshSelectedImage()
    }

    /// 当某个 scope 的数据发生变化时调用，按需刷新任务与选中。
    func reload(scope: Scope, selectTask taskID: String? = nil, image imageID: String? = nil) {
        lastError = nil
        switch scope {
        case .project:
            reloadProject()
            if let taskID {
                selectScope(.project, taskID: taskID, imageID: imageID)
                return
            }
        case .app:
            reloadApp()
            if let taskID {
                selectScope(.app, taskID: taskID, imageID: imageID)
                return
            }
        }
        refreshSelectedImage()
    }

    private func reloadProject() {
        guard !projectStoragePath.isEmpty else {
            projectTasks = []
            return
        }
        do {
            projectTasks = try documentStore.listTasks(storagePath: projectStoragePath)
        } catch {
            projectTasks = []
            lastError = error.localizedDescription
        }
    }

    private func reloadApp() {
        guard !appStoragePath.isEmpty else {
            appTasks = []
            return
        }
        do {
            appTasks = try documentStore.listTasks(storagePath: appStoragePath)
        } catch {
            appTasks = []
            lastError = error.localizedDescription
        }
    }

    private func refreshSelectedImage() {
        guard let selectedTaskID,
              let scope = tasks(for: selectedScope).first(where: { $0.id == selectedTaskID }) else {
            selectedImage = nil
            return
        }
        do {
            let imageID = selectedImageID ?? scope.images.sorted(by: { $0.order < $1.order }).first?.id ?? ""
            let image: AppStorePromoResolvedImage
            do {
                image = try documentStore.readImage(
                    storagePath: storagePath(for: selectedScope),
                    taskSlug: selectedTaskID,
                    imageSlug: imageID,
                    localeIdentifier: selectedLocaleIdentifier
                )
            } catch AppStorePromoStoreError.localeNotFound {
                image = try documentStore.readImage(
                    storagePath: storagePath(for: selectedScope),
                    taskSlug: selectedTaskID,
                    imageSlug: imageID
                )
            }
            selectedImage = image
            selectedImageID = image.image.id
            selectedLocaleIdentifier = image.localeIdentifier
            self.selectedTaskID = image.task.id
            let allowed = AppStorePromoDisplaySpec.presets(for: image.task.deviceFamily)
            if !allowed.contains(where: { $0.displayType == selectedDisplayType }) {
                selectedDisplayType = allowed.first?.displayType ?? "APP_DESKTOP"
            }
        } catch {
            selectedImage = nil
        }
    }

    // MARK: - Selection

    func selectScope(_ scope: Scope, taskID: String, imageID: String?) {
        if selectedScope != scope || selectedTaskID != taskID || selectedImageID != imageID {
            selectedLocaleIdentifier = nil
        }
        selectedScope = scope
        selectedTaskID = taskID
        selectedImageID = imageID
        reload()
    }

    func select(taskID: String, imageID: String?) {
        // 查找该 taskID 所在的 scope。
        if projectTasks.contains(where: { $0.id == taskID }) {
            selectScope(.project, taskID: taskID, imageID: imageID)
            return
        }
        if appTasks.contains(where: { $0.id == taskID }) {
            selectScope(.app, taskID: taskID, imageID: imageID)
            return
        }
        // 兜底：保持当前 scope，仅记录 ID。
        selectedTaskID = taskID
        selectedImageID = imageID
        refreshSelectedImage()
    }

    // MARK: - Mutations

    func selectLocale(_ localeIdentifier: String) {
        selectedLocaleIdentifier = localeIdentifier
        refreshSelectedImage()
    }

    func addLocale(_ localeIdentifier: String) {
        guard let selectedImage else { return }
        do {
            let localized = try documentStore.addLocalization(
                localeIdentifier,
                copying: selectedImage.localeIdentifier,
                storagePath: storagePath(for: selectedScope),
                taskSlug: selectedImage.task.id,
                imageSlug: selectedImage.image.id
            )
            selectedLocaleIdentifier = localized.localeIdentifier
            reload(scope: selectedScope, selectTask: localized.task.id, image: localized.image.id)
        } catch {
            setError(error)
        }
    }

    func deleteTask(scope: Scope, id: String) {
        do {
            try documentStore.deleteTask(storagePath: storagePath(for: scope), taskSlug: id)
            if selectedScope == scope, selectedTaskID == id {
                selectedTaskID = nil
                selectedImageID = nil
                selectedLocaleIdentifier = nil
                selectedImage = nil
            }
            reload()
        } catch {
            setError(error)
        }
    }

    func deleteImage(scope: Scope, taskID: String, imageID: String) {
        do {
            try documentStore.deleteImage(storagePath: storagePath(for: scope), taskSlug: taskID, imageSlug: imageID)
            if selectedScope == scope, selectedTaskID == taskID, selectedImageID == imageID {
                selectedImageID = nil
            }
            reload(scope: scope, selectTask: taskID)
        } catch {
            setError(error)
        }
    }

    func setError(_ error: Error) { lastError = error.localizedDescription }
}
