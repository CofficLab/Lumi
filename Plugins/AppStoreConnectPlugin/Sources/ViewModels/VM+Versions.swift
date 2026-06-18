import Foundation

extension VM {
    func loadVersions() async {
        guard let app = selectedApp else {
            Self.logger.warning("\(self.t)loadVersions skipped: no selectedApp")
            return
        }
        Self.logger.info("\(self.t)loadVersions starting for app: \(app.name) (id: \(app.id), platform: \(app.platform ?? "nil"))")
        await runBusy {
            let rawVersions = try await client.listVersions(appID: app.id)
            Self.logger.info("\(self.t)raw versions fetched: \(rawVersions.count)")
            versions = rawVersions
            let versionCount = versions.count
            let filteredVersions = sidebarVersions
            Self.logger.info("\(self.t)versions set: \(versionCount), platform filter: \(app.platform ?? "nil")")
            Self.logger.info("\(self.t)sidebarVersions after filter: \(filteredVersions.count)")
            if Self.verbose {
                filteredVersions.forEach { v in
                    Self.logger.info("\(self.t)  - \(v.versionString) (state: \(v.appStoreState), platform: \(v.platform))")
                }
            }
            selectedVersion = filteredVersions.first
            if selectedVersion != nil {
                await loadLocalizations()
            } else {
                Self.logger.warning("\(self.t)no sidebarVersions to select")
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

    func openDistribution(for version: AppStoreVersion) {
        selectVersion(version)
    }

    func openCoverArtMaker() {
        page = .coverArt
    }

    func releaseVersion(_ version: AppStoreVersion) async {
        guard version.isPendingDeveloperRelease else { return }
        await runBusy(forceRefresh: true) {
            try await client.releaseVersion(versionID: version.id)
            guard let app = selectedApp else { return }
            versions = try await client.listVersions(appID: app.id)
            client.pruneStaleVersionCache(keepingVersionIDs: Set(versions.map(\.id)))
            if let updated = versions.first(where: { $0.id == version.id }) {
                selectedVersion = updated
            }
        }
    }

    func reloadDistributionFromNetwork() async throws {
        if let app = selectedApp {
            versions = try await client.listVersions(appID: app.id)
            client.pruneStaleVersionCache(keepingVersionIDs: Set(versions.map(\.id)))
            if let selectedVersion,
               sidebarVersions.contains(where: { $0.id == selectedVersion.id }) {
                self.selectedVersion = sidebarVersions.first { $0.id == selectedVersion.id }
            } else {
                selectedVersion = sidebarVersions.first
            }
        }
        try await reloadLocalizationsFromNetwork()
    }
}
