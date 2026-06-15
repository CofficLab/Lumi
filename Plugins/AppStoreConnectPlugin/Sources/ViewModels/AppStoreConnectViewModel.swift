import AppKit
import Combine
import Foundation

@MainActor
final class AppStoreConnectViewModel: ObservableObject {
    static let shared = AppStoreConnectViewModel()

    enum Page: String, CaseIterable, Identifiable {
        case account
        case apps
        case distribution
        case xcodeCloud

        var id: String { rawValue }

        var title: String {
            switch self {
            case .account: return AppStoreConnectLocalization.string("Account")
            case .apps: return AppStoreConnectLocalization.string("Apps")
            case .distribution: return AppStoreConnectLocalization.string("Distribution")
            case .xcodeCloud: return AppStoreConnectLocalization.string("Xcode Cloud")
            }
        }

        var systemImage: String {
            switch self {
            case .account: return "key"
            case .apps: return "square.grid.2x2"
            case .distribution: return "shippingbox"
            case .xcodeCloud: return "cloud"
            }
        }
    }

    static let generalPages: [Page] = [.account, .apps]

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
    @Published var screenshots: [AppScreenshot] = []
    @Published var screenshotsBySetID: [String: [AppScreenshot]] = [:]
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

    var availableScreenshotDisplayTypes: [String] {
        let loaded = screenshotSets.map(\.screenshotDisplayType)
        let merged = loaded + screenshotDisplayTypes
        var seen = Set<String>()
        return merged.filter { seen.insert($0).inserted }
    }

    private let credentialStore: CredentialStore
    private let client: ConnectClient

    init(credentialStore: CredentialStore = .shared) {
        self.credentialStore = credentialStore
        let loadedCredentials = credentialStore.load()
        self.credentials = loadedCredentials
        self.hasStoredPrivateKey = !loadedCredentials.privateKey.isEmpty
        self.client = ConnectClient(credentialsProvider: { credentialStore.load() })
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

    var selectedScreenshotSet: ScreenshotSet? {
        screenshotSets.first { $0.screenshotDisplayType == selectedScreenshotDisplayType }
    }

    var sidebarVersions: [AppStoreVersion] {
        AppStoreVersion.sidebarVersions(from: versions, appPlatform: selectedApp?.platform)
    }

    func saveCredentials() {
        credentialStore.save(credentials)
        hasStoredPrivateKey = !credentials.privateKey.isEmpty
        connectionStatus = credentials.isComplete
            ? AppStoreConnectLocalization.string("Credentials configured")
            : AppStoreConnectLocalization.string("Credentials incomplete")
        client.invalidateCache()
    }

    func disconnect() {
        credentialStore.clear()
        client.invalidateCache()
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
        screenshots = []
        screenshotsBySetID = [:]
        clearXcodeCloudState()
    }

    func testConnection() async {
        await runBusy(forceRefresh: true) {
            try await client.testConnection()
            connectionStatus = AppStoreConnectLocalization.string("Connected")
        }
    }

    func refreshCurrentPage() async {
        await runBusy(forceRefresh: true) {
            switch page {
            case .account:
                try await client.testConnection()
                connectionStatus = AppStoreConnectLocalization.string("Connected")
            case .apps:
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                apps = try await client.listApps(search: query.isEmpty ? nil : query)
                connectionStatus = AppStoreConnectLocalization.string("Connected")
            case .distribution:
                try await reloadDistributionFromNetwork()
            case .xcodeCloud:
                if selectedCiWorkflow != nil {
                    try await reloadSelectedCiWorkflowDetailFromNetwork()
                } else if selectedCiProduct != nil {
                    try await reloadCiWorkflowsFromNetwork()
                } else {
                    try await reloadCiProductsFromNetwork()
                }
            }
        }
    }

    func loadApps() async {
        await runBusy {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            apps = try await client.listApps(search: query.isEmpty ? nil : query)
            connectionStatus = AppStoreConnectLocalization.string("Connected")
            if selectedApp == nil {
                selectedApp = apps.first
            } else if let selectedApp,
                      !apps.contains(where: { $0.id == selectedApp.id }) {
                self.selectedApp = apps.first
            }
        }
    }

    func navigate(to page: Page) {
        self.page = page
        Task { await preparePageIfNeeded(page) }
    }

    func preparePageIfNeeded(_ page: Page) async {
        guard credentials.isComplete else { return }
        switch page {
        case .apps where apps.isEmpty:
            await loadApps()
        case .distribution:
            if versions.isEmpty, selectedApp != nil {
                await loadVersions()
            } else if localizations.isEmpty, selectedVersion != nil {
                await loadLocalizations()
            } else if selectedLocalizationID != nil, screenshotSets.isEmpty {
                await loadScreenshotSets()
            }
        case .xcodeCloud where ciProducts.isEmpty:
            await loadCiProducts()
        default:
            break
        }
    }

    func selectApp(_ app: AppStoreApp, openDistribution: Bool = false) {
        let appChanged = selectedApp?.id != app.id
        selectedApp = app
        if appChanged {
            selectedVersion = nil
            versions = []
            localizations = []
            editedLocalization = nil
            pendingScreenshots = []
            screenshotSets = []
            screenshots = []
            screenshotsBySetID = [:]
            clearXcodeCloudSelection()
        }
        if openDistribution {
            page = .distribution
        }
        Task { await loadVersions() }
    }

    func openDistribution(for version: AppStoreVersion) {
        selectVersion(version)
    }

    func loadVersions() async {
        guard let app = selectedApp else { return }
        await runBusy {
            versions = try await client.listVersions(appID: app.id)
            selectedVersion = sidebarVersions.first
            if selectedVersion != nil {
                await loadLocalizations()
            }
        }
    }

    func selectVersion(_ version: AppStoreVersion) {
        selectedVersion = version
        page = .distribution
        localizations = []
        editedLocalization = nil
        pendingScreenshots = []
        screenshotSets = []
        screenshots = []
        screenshotsBySetID = [:]
        Task { await loadLocalizations() }
    }

    func loadLocalizations() async {
        guard let version = selectedVersion else { return }
        let preferredLocalizationID = selectedLocalizationID
        await runBusy {
            localizations = try await client.listLocalizations(versionID: version.id)
            if let preferredLocalizationID,
               localizations.contains(where: { $0.id == preferredLocalizationID }) {
                selectedLocalizationID = preferredLocalizationID
            } else if let primaryLocale = selectedApp?.primaryLocale,
                      let match = localizations.first(where: { $0.locale == primaryLocale }) {
                selectedLocalizationID = match.id
            } else {
                selectedLocalizationID = localizations.first?.id
            }
            editedLocalization = localizations.first { $0.id == selectedLocalizationID }
            metadataIsDirty = false
            if let localizationID = selectedLocalizationID {
                try await applyScreenshotPayload(
                    try await client.loadScreenshotSets(localizationID: localizationID)
                )
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

    func loadScreenshotSets(forceRefresh: Bool = false) async {
        guard let localizationID = selectedLocalizationID else { return }
        await runBusy(forceRefresh: forceRefresh) {
            try await applyScreenshotPayload(
                try await client.loadScreenshotSets(localizationID: localizationID)
            )
        }
    }

    func loadScreenshots() async throws {
        guard let set = selectedScreenshotSet else {
            screenshots = []
            return
        }

        if let cached = screenshotsBySetID[set.id] {
            screenshots = cached
            return
        }

        let loaded = try await client.listScreenshots(screenshotSetID: set.id)
        screenshotsBySetID[set.id] = loaded
        screenshots = loaded
    }

    func reloadScreenshotsForSelectedDisplayType(forceRefresh: Bool = false) async {
        await runBusy(forceRefresh: forceRefresh) {
            alignSelectedScreenshotDisplayType()
            try await loadScreenshots()
        }
    }

    private func applyScreenshotPayload(_ payload: ScreenshotSetsPayload) async throws {
        screenshotSets = payload.sets
        screenshotsBySetID = payload.screenshotsBySetID
        alignSelectedScreenshotDisplayType()
        try await loadScreenshots()

        if screenshots.isEmpty {
            for set in screenshotSets where screenshotsBySetID[set.id] == nil {
                let loaded = try await client.listScreenshots(screenshotSetID: set.id)
                if !loaded.isEmpty {
                    screenshotsBySetID[set.id] = loaded
                }
            }
            try await loadScreenshots()
        }
    }

    private func alignSelectedScreenshotDisplayType() {
        guard selectedScreenshotSet == nil, let first = screenshotSets.first else { return }
        selectedScreenshotDisplayType = first.screenshotDisplayType
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
            if set.screenshotDisplayType == selectedScreenshotDisplayType {
                screenshotsBySetID[set.id] = []
                try await loadScreenshots()
            }
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

    private func runBusy(forceRefresh: Bool = false, _ operation: () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        let previousPolicy = client.fetchPolicy
        if forceRefresh {
            client.fetchPolicy = .networkOnly
        }
        defer {
            client.fetchPolicy = previousPolicy
            isBusy = false
        }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadDistributionFromNetwork() async throws {
        if let app = selectedApp {
            versions = try await client.listVersions(appID: app.id)
            if let selectedVersion,
               sidebarVersions.contains(where: { $0.id == selectedVersion.id }) {
                self.selectedVersion = sidebarVersions.first { $0.id == selectedVersion.id }
            } else {
                selectedVersion = sidebarVersions.first
            }
        }
        try await reloadLocalizationsFromNetwork()
    }

    private func reloadLocalizationsFromNetwork() async throws {
        guard let version = selectedVersion else { return }
        let preferredLocalizationID = selectedLocalizationID
        localizations = try await client.listLocalizations(versionID: version.id)
        if let preferredLocalizationID,
           localizations.contains(where: { $0.id == preferredLocalizationID }) {
            selectedLocalizationID = preferredLocalizationID
        } else if let primaryLocale = selectedApp?.primaryLocale,
                  let match = localizations.first(where: { $0.locale == primaryLocale }) {
            selectedLocalizationID = match.id
        } else {
            selectedLocalizationID = localizations.first?.id
        }
        editedLocalization = localizations.first { $0.id == selectedLocalizationID }
        metadataIsDirty = false
        if let localizationID = selectedLocalizationID {
            try await applyScreenshotPayload(
                try await client.loadScreenshotSets(localizationID: localizationID)
            )
        }
    }

    private func reloadScreenshotSetsFromNetwork() async throws {
        guard let localizationID = selectedLocalizationID else { return }
        try await applyScreenshotPayload(
            try await client.loadScreenshotSets(localizationID: localizationID)
        )
    }

    private func reloadCiProductsFromNetwork() async throws {
        ciProducts = try await client.listCiProducts()
        selectBestCiProduct()
        if selectedCiProduct != nil {
            try await reloadCiWorkflowsFromNetwork()
        }
    }

    private func reloadCiWorkflowsFromNetwork() async throws {
        guard let product = selectedCiProduct else { return }
        ciWorkflows = try await client.listCiWorkflows(productID: product.id)
        if let current = selectedCiWorkflow,
           !ciWorkflows.contains(where: { $0.id == current.id }) {
            selectedCiWorkflow = ciWorkflows.first
        }
        updateCiWorkflowExportJSON()
    }

    private func reloadSelectedCiWorkflowDetailFromNetwork() async throws {
        guard let workflow = selectedCiWorkflow else { return }
        let detail = try await client.readCiWorkflow(id: workflow.id)
        selectedCiWorkflowDetail = detail
        replaceCiWorkflow(detail)
        ciBuildRuns = try await client.listCiBuildRuns(workflowID: detail.id)
        updateCiWorkflowExportJSON()
    }
}

private extension JSONEncoder {
    static var xcodeCloudExport: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
