import Foundation

extension VM {
    func refreshWorkspace() async {
        guard credentials.isComplete else { return }

        toast?.show(
            AppStoreConnectLocalization.string("Refreshing"),
            style: .info,
            duration: 1.2
        )

        await runBusy(forceRefresh: true) {
            try await reloadAppsFromNetwork()

            switch page {
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

        if let errorMessage {
            toast?.show(
                AppStoreConnectLocalization.string("Refresh failed"),
                detail: errorMessage,
                style: .error,
                duration: 3
            )
        } else {
            toast?.show(
                AppStoreConnectLocalization.string("Refreshed"),
                style: .success,
                duration: 1.8
            )
        }
    }

    func refreshCurrentPage() async {
        await runBusy(forceRefresh: true) {
            switch page {
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

    func navigate(to page: Page) {
        self.page = page
        Task { await preparePageIfNeeded(page) }
    }

    func preparePageIfNeeded(_ page: Page) async {
        guard credentials.isComplete else { return }
        switch page {
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
