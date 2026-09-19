import Foundation

extension VM {
    /// 工具栏刷新入口。
    ///
    /// 刷新过程静默执行：忙碌状态由页面内的加载遮罩表达，失败信息通过
    /// `errorMessage` 交给界面上的错误横幅呈现，因此这里不弹出任何 toast。
    func refreshWorkspace() async {
        guard credentials.isComplete else { return }

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
