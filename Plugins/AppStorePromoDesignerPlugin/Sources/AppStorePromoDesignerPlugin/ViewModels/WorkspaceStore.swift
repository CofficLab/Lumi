import AppStorePromoKit
import Foundation

@MainActor
final class WorkspaceStore: ObservableObject {
    static let shared = WorkspaceStore()

    @Published private(set) var tasks: [AppStorePromoTask] = []
    @Published private(set) var selectedImage: AppStorePromoResolvedImage?
    @Published var selectedTaskID: String?
    @Published var selectedImageID: String?
    @Published var selectedDisplayType = "APP_IPHONE_67"
    @Published var lastError: String?
    @Published var lastExportURL: URL?

    let documentStore = AppStorePromoDocumentStore()
    private(set) var persistenceDirectory: URL?

    private init() {}

    var storagePath: String { persistenceDirectory?.path ?? "" }

    func configure(persistenceDirectory: URL?) {
        guard self.persistenceDirectory?.standardizedFileURL != persistenceDirectory?.standardizedFileURL else { return }
        self.persistenceDirectory = persistenceDirectory
        if let persistenceDirectory {
            try? FileManager.default.createDirectory(at: persistenceDirectory, withIntermediateDirectories: true)
        }
        selectedTaskID = nil
        selectedImageID = nil
        reload()
    }

    func reload(selectTask taskID: String? = nil, image imageID: String? = nil) {
        guard !storagePath.isEmpty else {
            tasks = []
            selectedImage = nil
            return
        }
        do {
            tasks = try documentStore.listTasks(storagePath: storagePath)
            let previousTaskID = selectedTaskID
            selectedTaskID = taskID ?? selectedTaskID ?? tasks.first?.id
            guard let selectedTaskID,
                  let task = tasks.first(where: { $0.id == selectedTaskID }) else {
                selectedImage = nil
                return
            }
            let firstImageID = task.images.sorted(by: { $0.order < $1.order }).first?.id
            if let imageID {
                selectedImageID = imageID
            } else if taskID != nil, taskID != previousTaskID {
                selectedImageID = firstImageID
            } else if !task.images.contains(where: { $0.id == selectedImageID }) {
                selectedImageID = firstImageID
            }
            if let selectedImageID {
                selectedImage = try documentStore.readImage(
                    storagePath: storagePath,
                    taskSlug: selectedTaskID,
                    imageSlug: selectedImageID
                )
            } else {
                selectedImage = nil
            }
            let allowed = AppStorePromoDisplaySpec.presets(for: task.deviceFamily)
            if !allowed.contains(where: { $0.displayType == selectedDisplayType }) {
                selectedDisplayType = allowed.first?.displayType ?? "APP_DESKTOP"
            }
            lastError = nil
        } catch {
            selectedImage = nil
            lastError = error.localizedDescription
        }
    }

    func select(taskID: String, imageID: String?) {
        selectedTaskID = taskID
        selectedImageID = imageID
        reload(selectTask: taskID, image: imageID)
    }

    func deleteTask(id: String) {
        do {
            try documentStore.deleteTask(storagePath: storagePath, taskSlug: id)
            if selectedTaskID == id {
                selectedTaskID = nil
                selectedImageID = nil
            }
            reload()
        } catch {
            setError(error)
        }
    }

    func deleteImage(taskID: String, imageID: String) {
        do {
            try documentStore.deleteImage(storagePath: storagePath, taskSlug: taskID, imageSlug: imageID)
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
