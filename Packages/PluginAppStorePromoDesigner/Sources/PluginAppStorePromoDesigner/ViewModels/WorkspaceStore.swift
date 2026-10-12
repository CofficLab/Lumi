import KitAppStorePromo
import Foundation

@MainActor
final class WorkspaceStore: ObservableObject {
    static let shared = WorkspaceStore()

    /// 当前打开项目 `.lumi/app-store-promo` 下的任务列表。
    @Published private(set) var projectTasks: [AppStorePromoTask] = []

    @Published private(set) var selectedImage: AppStorePromoResolvedImage?
    @Published var selectedTaskID: String?
    @Published var selectedImageID: String?
    @Published var selectedLocaleIdentifier: String?
    @Published var selectedDisplayType = "APP_IPHONE_67"
    @Published var lastError: String?
    @Published var lastExportURL: URL?

    let documentStore = AppStorePromoDocumentStore()

    /// 项目内存储根目录（基于当前项目路径；nil 表示无打开项目）。
    private(set) var projectStorageDirectory: URL?
    /// 当前打开项目的路径。
    private(set) var currentProjectPath: String?

    private init() {}

    // MARK: - Paths

    /// 项目内存储路径字符串（无打开项目时为空）。
    var projectStoragePath: String { projectStorageDirectory?.path ?? "" }

    // MARK: - Configuration

    func setProjectStorage(projectPath: String?, projectStorageDirectory: URL?) {
        let resolvedPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPath = (resolvedPath?.isEmpty == false) ? resolvedPath : nil
        let resolvedDirectory = projectStorageDirectory?.standardizedFileURL
        guard self.currentProjectPath != normalizedPath || self.projectStorageDirectory != resolvedDirectory else { return }
        self.currentProjectPath = normalizedPath
        self.projectStorageDirectory = resolvedDirectory
        if let resolvedDirectory {
            try? FileManager.default.createDirectory(at: resolvedDirectory, withIntermediateDirectories: true)
        }
        reload()
    }

    // MARK: - Reload

    /// 重新加载项目任务列表以及当前选中图像。
    func reload() {
        lastError = nil
        reloadProject()
        refreshSelectedImage()
    }

    /// 当项目数据发生变化时调用，按需刷新任务与选中。
    func reload(selectTask taskID: String? = nil, image imageID: String? = nil) {
        lastError = nil
        reloadProject()
        if let taskID {
            if selectedTaskID != taskID || selectedImageID != imageID {
                selectedLocaleIdentifier = nil
            }
            selectedTaskID = taskID
            selectedImageID = imageID
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

    private func refreshSelectedImage() {
        guard let selectedTaskID,
              let task = projectTasks.first(where: { $0.id == selectedTaskID }) else {
            selectedImage = nil
            return
        }
        do {
            let imageID = selectedImageID ?? task.images.sorted(by: { $0.order < $1.order }).first?.id ?? ""
            let image: AppStorePromoResolvedImage
            do {
                image = try documentStore.readImage(
                    storagePath: projectStoragePath,
                    taskSlug: selectedTaskID,
                    imageSlug: imageID,
                    localeIdentifier: selectedLocaleIdentifier
                )
            } catch AppStorePromoStoreError.localeNotFound {
                image = try documentStore.readImage(
                    storagePath: projectStoragePath,
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

    func select(taskID: String, imageID: String?) {
        if selectedTaskID != taskID || selectedImageID != imageID {
            selectedLocaleIdentifier = nil
        }
        selectedTaskID = taskID
        selectedImageID = imageID
        reload()
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
                storagePath: projectStoragePath,
                taskSlug: selectedImage.task.id,
                imageSlug: selectedImage.image.id
            )
            selectedLocaleIdentifier = localized.localeIdentifier
            reload(selectTask: localized.task.id, image: localized.image.id)
        } catch {
            setError(error)
        }
    }

    func deleteTask(id: String) {
        do {
            try documentStore.deleteTask(storagePath: projectStoragePath, taskSlug: id)
            if selectedTaskID == id {
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

    func deleteImage(taskID: String, imageID: String) {
        do {
            try documentStore.deleteImage(storagePath: projectStoragePath, taskSlug: taskID, imageSlug: imageID)
            if selectedTaskID == taskID, selectedImageID == imageID {
                selectedImageID = nil
            }
            reload(selectTask: taskID)
        } catch {
            setError(error)
        }
    }

    func setError(_ error: Error) { lastError = error.localizedDescription }
}
