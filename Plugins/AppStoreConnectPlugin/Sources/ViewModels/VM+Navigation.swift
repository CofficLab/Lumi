import Foundation

extension VM {
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
            case .coverArt:
                break
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

    func navigate(to page: Page) {
        if Self.generalPages.contains(page) {
            selectedVersion = nil
        }
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
}
