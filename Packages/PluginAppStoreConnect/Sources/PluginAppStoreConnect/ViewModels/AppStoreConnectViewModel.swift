import AppKit
import Combine
import Foundation

@MainActor
final class AppStoreConnectViewModel: ObservableObject {
    static let shared = AppStoreConnectViewModel()

    enum Page: String, CaseIterable, Identifiable {
        case account
        case versions
        case metadata
        case screenshots
        case xcodeCloud

        var id: String { rawValue }

        var title: String {
            switch self {
            case .account: return AppStoreConnectLocalization.string("Account")
            case .versions: return AppStoreConnectLocalization.string("Versions")
            case .metadata: return AppStoreConnectLocalization.string("Metadata")
            case .screenshots: return AppStoreConnectLocalization.string("Screenshots")
            case .xcodeCloud: return AppStoreConnectLocalization.string("Xcode Cloud")
            }
        }

        var systemImage: String {
            switch self {
            case .account: return "key"
            case .versions: return "clock.arrow.circlepath"
            case .metadata: return "text.alignleft"
            case .screenshots: return "photo.on.rectangle"
            case .xcodeCloud: return "cloud"
            }
        }
    }

    static let generalPages: [Page] = [.account]
    static let appPages: [Page] = [.versions, .metadata, .screenshots, .xcodeCloud]

    @Published var page: Page = .account
    @Published var credentials: AppStoreConnectCredentials
    @Published var hasStoredPrivateKey: Bool
    @Published var connectionStatus = AppStoreConnectLocalization.string("Not connected")
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var apps: [AppStoreApp] = []
    @Published var selectedApp: AppStoreApp?
    @Published var versions: [AppStoreVersion] = []
    @Published var selectedVersion: AppStoreVersion?
    @Published var localizations: [AppStoreVersionLocalization] = []
    @Published var selectedLocalizationID: String?
    @Published var editedLocalization: AppStoreVersionLocalization?
    @Published var pendingScreenshots: [PendingScreenshot] = []
    @Published var screenshotSets: [ScreenshotSet] = []
    @Published var selectedScreenshotDisplayType = "APP_IPHONE_67"
    @Published var metadataIsDirty = false
    @Published var ciProducts: [CiProduct] = []
    @Published var selectedCiProduct: CiProduct?
    @Published var ciWorkflows: [CiWorkflow] = []
    @Published var selectedCiWorkflow: CiWorkflow?
    @Published var selectedCiWorkflowDetail: CiWorkflow?
    @Published var ciBuildRuns: [CiBuildRun] = []
    @Published var ciSourceBranchOrTag = ""
    @Published var ciWorkflowExportJSON = ""

    let screenshotDisplayTypes = [
        "APP_IPHONE_67",
        "APP_IPHONE_65",
        "APP_IPHONE_61",
        "APP_IPHONE_58",
        "APP_IPAD_PRO_3GEN_129",
        "APP_IPAD_PRO_3GEN_11",
        "APP_DESKTOP"
    ]

    private let credentialStore: AppStoreConnectCredentialStore
    private let client: AppStoreConnectClient

    init(credentialStore: AppStoreConnectCredentialStore = .shared) {
        self.credentialStore = credentialStore
        let loadedCredentials = credentialStore.load()
        self.credentials = loadedCredentials
        self.hasStoredPrivateKey = !loadedCredentials.privateKey.isEmpty
        self.client = AppStoreConnectClient(credentialsProvider: { credentialStore.load() })
        if loadedCredentials.isComplete {
            connectionStatus = AppStoreConnectLocalization.string("Credentials configured")
        }
    }

    var filteredApps: [AppStoreApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.lowercased().contains(query) ||
            $0.bundleID.lowercased().contains(query) ||
            $0.sku.lowercased().contains(query)
        }
    }

    var selectedLocalization: AppStoreVersionLocalization? {
        guard let selectedLocalizationID else { return nil }
        return localizations.first { $0.id == selectedLocalizationID }
    }

    func saveCredentials() {
        credentialStore.save(credentials)
        hasStoredPrivateKey = !credentials.privateKey.isEmpty
        connectionStatus = credentials.isComplete
            ? AppStoreConnectLocalization.string("Credentials configured")
            : AppStoreConnectLocalization.string("Credentials incomplete")
    }

    func disconnect() {
        credentialStore.clear()
        credentials = AppStoreConnectCredentials(issuerID: "", keyID: "", privateKey: "")
        hasStoredPrivateKey = false
        connectionStatus = AppStoreConnectLocalization.string("Not connected")
        apps = []
        selectedApp = nil
        versions = []
        selectedVersion = nil
        localizations = []
        editedLocalization = nil
        pendingScreenshots = []
        screenshotSets = []
        clearXcodeCloudState()
    }

    func testConnection() async {
        await runBusy {
            try await client.testConnection()
            connectionStatus = AppStoreConnectLocalization.string("Connected")
        }
    }

    func loadApps() async {
        await runBusy {
            apps = try await client.listApps()
            connectionStatus = AppStoreConnectLocalization.string("Connected")
            if selectedApp == nil {
                selectedApp = apps.first
            }
        }
    }

    func selectApp(_ app: AppStoreApp) {
        selectedApp = app
        selectedVersion = nil
        versions = []
        localizations = []
        editedLocalization = nil
        pendingScreenshots = []
        screenshotSets = []
        clearXcodeCloudSelection()
        page = .versions
        Task { await loadVersions() }
    }

    func loadVersions() async {
        guard let app = selectedApp else { return }
        await runBusy {
            versions = try await client.listVersions(appID: app.id)
            selectedVersion = versions.first
            if selectedVersion != nil {
                await loadLocalizations()
            }
        }
    }

    func selectVersion(_ version: AppStoreVersion) {
        selectedVersion = version
        localizations = []
        editedLocalization = nil
        pendingScreenshots = []
        screenshotSets = []
        Task { await loadLocalizations() }
    }

    func loadLocalizations() async {
        guard let version = selectedVersion else { return }
        await runBusy {
            localizations = try await client.listLocalizations(versionID: version.id)
            selectedLocalizationID = localizations.first?.id
            editedLocalization = localizations.first
            metadataIsDirty = false
            if let localizationID = selectedLocalizationID {
                screenshotSets = try await client.listScreenshotSets(localizationID: localizationID)
            }
        }
    }

    func selectLocalization(id: String) {
        selectedLocalizationID = id
        editedLocalization = localizations.first { $0.id == id }
        metadataIsDirty = false
        pendingScreenshots = []
        Task { await loadScreenshotSets() }
    }

    func markMetadataDirty() {
        metadataIsDirty = true
    }

    func saveMetadata() async {
        guard let editedLocalization else { return }
        await runBusy {
            let updated = try await client.updateLocalization(editedLocalization)
            if let index = localizations.firstIndex(where: { $0.id == updated.id }) {
                localizations[index] = updated
            }
            self.editedLocalization = updated
            metadataIsDirty = false
        }
    }

    func loadScreenshotSets() async {
        guard let localizationID = selectedLocalizationID else { return }
        await runBusy {
            screenshotSets = try await client.listScreenshotSets(localizationID: localizationID)
        }
    }

    func addScreenshotFiles(_ urls: [URL]) {
        var newItems: [PendingScreenshot] = []
        for url in urls {
            guard let image = NSImage(contentsOf: url),
                  let representation = image.representations.first else {
                newItems.append(PendingScreenshot(
                    url: url,
                    width: 0,
                    height: 0,
                    displayType: selectedScreenshotDisplayType,
                    status: .invalid(AppStoreConnectLocalization.string("Not a readable image"))
                ))
                continue
            }

            let width = representation.pixelsWide
            let height = representation.pixelsHigh
            let status = validateScreenshot(width: width, height: height)
            newItems.append(PendingScreenshot(
                url: url,
                width: width,
                height: height,
                displayType: selectedScreenshotDisplayType,
                status: status
            ))
        }
        pendingScreenshots.append(contentsOf: newItems)
    }

    func removeScreenshot(_ screenshot: PendingScreenshot) {
        pendingScreenshots.removeAll { $0.id == screenshot.id }
    }

    func ensureScreenshotSet() async {
        guard let localizationID = selectedLocalizationID else { return }
        await runBusy {
            if screenshotSets.contains(where: { $0.screenshotDisplayType == selectedScreenshotDisplayType }) {
                return
            }
            let set = try await client.createScreenshotSet(
                localizationID: localizationID,
                displayType: selectedScreenshotDisplayType
            )
            screenshotSets.append(set)
        }
    }

    func loadCiProducts() async {
        await runBusy {
            ciProducts = try await client.listCiProducts()
            selectBestCiProduct()
            if selectedCiProduct != nil {
                await loadCiWorkflows()
            }
        }
    }

    func selectCiProduct(_ product: CiProduct) {
        selectedCiProduct = product
        ciWorkflows = []
        selectedCiWorkflow = nil
        selectedCiWorkflowDetail = nil
        ciBuildRuns = []
        ciWorkflowExportJSON = ""
        Task { await loadCiWorkflows() }
    }

    func loadCiWorkflows() async {
        guard let product = selectedCiProduct else { return }
        await runBusy {
            ciWorkflows = try await client.listCiWorkflows(productID: product.id)
            selectedCiWorkflow = ciWorkflows.first
            if selectedCiWorkflow != nil {
                await loadSelectedCiWorkflowDetail()
            } else {
                selectedCiWorkflowDetail = nil
                ciBuildRuns = []
            }
        }
    }

    func selectCiWorkflow(_ workflow: CiWorkflow) {
        selectedCiWorkflow = workflow
        selectedCiWorkflowDetail = nil
        ciBuildRuns = []
        ciWorkflowExportJSON = ""
        Task { await loadSelectedCiWorkflowDetail() }
    }

    func loadSelectedCiWorkflowDetail() async {
        guard let workflow = selectedCiWorkflow else { return }
        await runBusy {
            selectedCiWorkflowDetail = try await client.readCiWorkflow(id: workflow.id)
            ciBuildRuns = try await client.listCiBuildRuns(workflowID: workflow.id)
            updateCiWorkflowExportJSON()
        }
    }

    func loadCiBuildRuns() async {
        guard let workflow = selectedCiWorkflow else { return }
        await runBusy {
            ciBuildRuns = try await client.listCiBuildRuns(workflowID: workflow.id)
        }
    }

    func startCiBuildRun() async {
        guard let workflow = selectedCiWorkflow else { return }
        await runBusy {
            let buildRun = try await client.startCiBuildRun(
                workflowID: workflow.id,
                branch: ciSourceBranchOrTag
            )
            ciBuildRuns.insert(buildRun, at: 0)
            ciBuildRuns = try await client.listCiBuildRuns(workflowID: workflow.id)
        }
    }

    func toggleSelectedCiWorkflowEnabled() async {
        guard let workflow = selectedCiWorkflowDetail ?? selectedCiWorkflow else { return }
        await runBusy {
            let updated = try await client.updateCiWorkflowEnabled(id: workflow.id, isEnabled: !workflow.isEnabled)
            replaceCiWorkflow(updated)
            selectedCiWorkflow = updated
            selectedCiWorkflowDetail = updated
            updateCiWorkflowExportJSON()
        }
    }

    func copySelectedCiWorkflowConfiguration() {
        updateCiWorkflowExportJSON()
        guard !ciWorkflowExportJSON.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ciWorkflowExportJSON, forType: .string)
    }

    private func validateScreenshot(width: Int, height: Int) -> PendingScreenshot.Status {
        guard width > 0, height > 0 else {
            return .invalid(AppStoreConnectLocalization.string("Image has no pixel size"))
        }
        guard width >= 320, height >= 320 else {
            return .invalid(AppStoreConnectLocalization.string("Image is too small"))
        }
        return .ready
    }

    private func selectBestCiProduct() {
        guard selectedCiProduct == nil else { return }
        guard let selectedApp else {
            selectedCiProduct = ciProducts.first
            return
        }
        selectedCiProduct = ciProducts.first {
            $0.appID == selectedApp.id ||
            $0.primaryAppID == selectedApp.id ||
            $0.bundleID == selectedApp.bundleID
        } ?? ciProducts.first
    }

    private func clearXcodeCloudSelection() {
        selectedCiProduct = nil
        ciWorkflows = []
        selectedCiWorkflow = nil
        selectedCiWorkflowDetail = nil
        ciBuildRuns = []
        ciWorkflowExportJSON = ""
    }

    private func clearXcodeCloudState() {
        ciProducts = []
        clearXcodeCloudSelection()
        ciSourceBranchOrTag = ""
    }

    private func replaceCiWorkflow(_ workflow: CiWorkflow) {
        if let index = ciWorkflows.firstIndex(where: { $0.id == workflow.id }) {
            ciWorkflows[index] = workflow
        }
    }

    private func updateCiWorkflowExportJSON() {
        guard let workflow = selectedCiWorkflowDetail ?? selectedCiWorkflow,
              let data = try? JSONEncoder.xcodeCloudExport.encode(CiWorkflowExport(workflow: workflow)),
              let value = String(data: data, encoding: .utf8) else {
            ciWorkflowExportJSON = ""
            return
        }
        ciWorkflowExportJSON = value
    }

    private func runBusy(_ operation: () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension JSONEncoder {
    static var xcodeCloudExport: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
