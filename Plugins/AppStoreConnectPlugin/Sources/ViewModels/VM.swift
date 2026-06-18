import AppKit
import Combine
import Foundation
import os
import SuperLogKit

@MainActor
final class VM: ObservableObject, SuperLog {
    nonisolated static let emoji = "🏪"
    nonisolated static let verbose = true
    static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-store-connect")

    static let shared = VM()

    enum Page: String, CaseIterable, Identifiable {
        case account
        case apps
        case distribution
        case coverArt
        case xcodeCloud

        var id: String { rawValue }

        var title: String {
            switch self {
            case .account: return AppStoreConnectLocalization.string("Account")
            case .apps: return AppStoreConnectLocalization.string("Apps")
            case .distribution: return AppStoreConnectLocalization.string("Distribution")
            case .coverArt: return AppStoreConnectLocalization.string("Cover Art Maker")
            case .xcodeCloud: return AppStoreConnectLocalization.string("Xcode Cloud")
            }
        }

        var systemImage: String {
            switch self {
            case .account: return "key"
            case .apps: return "square.grid.2x2"
            case .distribution: return "shippingbox"
            case .coverArt: return "photo.artframe"
            case .xcodeCloud: return "cloud"
            }
        }

        var showsTopBar: Bool {
            switch self {
            case .account, .apps, .coverArt: return false
            case .distribution, .xcodeCloud: return true
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
    @Published var coverArtItems: [CoverArtManifest] = []
    @Published var selectedCoverArtSlug: String?
    @Published var coverArtPreviewDisplayType: String?
    @Published var coverArtHTML = ""
    @Published var coverArtFileURL: URL?
    @Published var coverArtReloadToken = UUID()

    let coverArtStore = CoverArtDocumentStore()

    static let screenshotDisplayTypesByPlatform: [String: [String]] = [
        "IOS": [
            "APP_IPHONE_67",
            "APP_IPHONE_65",
            "APP_IPHONE_61",
            "APP_IPHONE_58",
            "APP_IPAD_PRO_3GEN_129",
            "APP_IPAD_PRO_3GEN_11"
        ],
        "MAC_OS": [
            "APP_DESKTOP"
        ],
        "TV_OS": [
            "APP_APPLE_TV"
        ],
        "VISION_OS": []
    ]

    static let fallbackScreenshotDisplayTypes = [
        "APP_IPHONE_67",
        "APP_IPHONE_65",
        "APP_IPHONE_61",
        "APP_IPHONE_58",
        "APP_IPAD_PRO_3GEN_129",
        "APP_IPAD_PRO_3GEN_11"
    ]

    static let loadingOverlayDelay: Duration = .milliseconds(500)

    let credentialStore: CredentialStore
    let client: ConnectClient
    let localStore: AppStoreConnectPluginLocalStore

    init(
        credentialStore: CredentialStore = .shared,
        localStore: AppStoreConnectPluginLocalStore = .shared
    ) {
        self.credentialStore = credentialStore
        self.localStore = localStore
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

    var isReadOnlyVersion: Bool {
        selectedVersion?.isReadOnlyVersion ?? false
    }

    var availableScreenshotDisplayTypes: [String] {
        let loaded = screenshotSets.map(\.screenshotDisplayType)
        let defaults = defaultScreenshotDisplayTypesForSelectedPlatform()
        let merged = loaded + defaults
        var seen = Set<String>()
        return merged.filter { seen.insert($0).inserted }
    }

    var sidebarVersions: [AppStoreVersion] {
        let result = AppStoreVersion.sidebarVersions(from: versions, appPlatform: selectedApp?.platform)
        if Self.verbose {
            let app = self.selectedApp
            Self.logger.info("\(self.t)sidebarVersions computed: \(result.count) versions for app: \(app?.name ?? "nil") (platform: \(app?.platform ?? "nil"))")
            if result.isEmpty && !versions.isEmpty {
                let platforms = Set(versions.map(\.platform))
                Self.logger.warning("\(self.t)sidebarVersions is empty but raw versions count is \(self.versions.count). Input platforms: \(platforms)")
            }
        }
        return result
    }
}
