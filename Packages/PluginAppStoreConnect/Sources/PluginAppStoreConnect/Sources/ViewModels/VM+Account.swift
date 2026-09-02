import Foundation

extension VM {
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
        Task {
            await ScreenshotImageCache.shared.clear()
        }
    }

    func testConnection() async {
        await runBusy(forceRefresh: true) {
            try await client.testConnection()
            connectionStatus = AppStoreConnectLocalization.string("Connected")
        }
    }
}
