import AppStorePromoKit
import Foundation

@MainActor
final class AppStorePromoWorkspaceStore: ObservableObject {
    static let shared = AppStorePromoWorkspaceStore()

    @Published private(set) var projects: [AppStorePromoProject] = []
    @Published private(set) var selectedPage: AppStorePromoResolvedPage?
    @Published var selectedProjectID: String?
    @Published var selectedPageID: String?
    @Published var selectedDisplayType = "APP_IPHONE_67"
    @Published var lastError: String?
    @Published var lastExportURL: URL?

    let documentStore = AppStorePromoDocumentStore()

    private init() {}

    var currentProjectPath: String { AppStorePromoRuntime.currentProjectPath }

    func reload(selectProject projectID: String? = nil, page pageID: String? = nil) {
        guard !currentProjectPath.isEmpty else {
            projects = []
            selectedPage = nil
            return
        }
        do {
            projects = try documentStore.listProjects(projectPath: currentProjectPath)
            selectedProjectID = projectID ?? selectedProjectID ?? projects.first?.id
            guard let selectedProjectID,
                  let project = projects.first(where: { $0.id == selectedProjectID }) else {
                selectedPage = nil
                return
            }
            selectedPageID = pageID ?? selectedPageID ?? project.pages.sorted(by: { $0.order < $1.order }).first?.id
            if let selectedPageID {
                selectedPage = try documentStore.readPage(
                    projectPath: currentProjectPath,
                    projectSlug: selectedProjectID,
                    pageSlug: selectedPageID
                )
            } else {
                selectedPage = nil
            }
            let allowed = AppStorePromoDisplaySpec.presets(for: project.deviceFamily)
            if !allowed.contains(where: { $0.displayType == selectedDisplayType }) {
                selectedDisplayType = allowed.first?.displayType ?? "APP_DESKTOP"
            }
            lastError = nil
        } catch {
            selectedPage = nil
            lastError = error.localizedDescription
        }
    }

    func select(projectID: String, pageID: String?) {
        selectedProjectID = projectID
        selectedPageID = pageID
        reload(selectProject: projectID, page: pageID)
    }

    func setError(_ error: Error) { lastError = error.localizedDescription }
}
