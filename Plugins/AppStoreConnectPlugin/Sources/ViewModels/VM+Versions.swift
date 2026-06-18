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
        reloadCoverArtList()
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

    func suggestedVersionString(for platform: String) -> String {
        AppStoreVersion.suggestedNextVersionString(for: platform, in: versions)
    }

    func prepareCreateVersionForm() async {
        guard let app = selectedApp else { return }
        guard versions.isEmpty else { return }
        await runBusy {
            versions = try await client.listVersions(appID: app.id)
        }
    }

    func availablePlatformsForVersionCreate() -> [String] {
        AppStoreVersion.platformsForVersionCreate(
            appPlatform: selectedApp?.platform,
            versions: versions
        )
    }

    func isPlatformAvailableForVersionCreate(_ platform: String) -> Bool {
        AppStoreVersion.isPlatformAvailableForVersionCreate(platform, versions: versions)
    }

    var canCreateVersion: Bool {
        guard selectedApp != nil else { return false }
        return availablePlatformsForVersionCreate().contains { isPlatformAvailableForVersionCreate($0) }
    }

    func createVersion(
        versionString: String,
        platform: String,
        releaseType: String
    ) async -> Bool {
        guard let app = selectedApp else { return false }

        var createdVersionID: String?
        await runBusy(forceRefresh: true) {
            let validated = try AppStoreVersion.validateCreate(
                versionString: versionString,
                platform: platform,
                versions: versions
            )

            let created = try await client.createVersion(
                appID: app.id,
                versionString: validated.versionString,
                platform: validated.platform,
                releaseType: releaseType
            )
            createdVersionID = created.id

            try await ensurePrimaryLocalization(
                for: created,
                platform: validated.platform,
                primaryLocale: app.primaryLocale
            )

            versions = try await client.listVersions(appID: app.id)
            client.pruneStaleVersionCache(keepingVersionIDs: Set(versions.map(\.id)))
            selectedVersion = versions.first { $0.id == created.id } ?? created
            page = .distribution
        }

        guard errorMessage == nil, createdVersionID != nil else { return false }
        await loadLocalizations()
        return true
    }

    private func ensurePrimaryLocalization(
        for created: AppStoreVersion,
        platform: String,
        primaryLocale: String
    ) async throws {
        let existing = try await client.listLocalizations(versionID: created.id)
        guard existing.isEmpty else { return }

        let locale = primaryLocale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "en-US"
            : primaryLocale
        let attributes = await copiedLocalizationAttributes(
            platform: platform,
            primaryLocale: locale
        )

        do {
            _ = try await client.createLocalization(
                versionID: created.id,
                locale: locale,
                attributes: attributes
            )
        } catch {
            Self.logger.warning("\(self.t)primary localization create failed for version \(created.id): \(error.localizedDescription)")
        }
    }

    private func copiedLocalizationAttributes(
        platform: String,
        primaryLocale: String
    ) async -> AppStoreVersionLocalization.CreateAttributes {
        guard let sourceVersion = AppStoreVersion.latestVersion(on: platform, in: versions) else {
            return AppStoreVersionLocalization.CreateAttributes()
        }

        do {
            let sourceLocalizations = try await client.listLocalizations(versionID: sourceVersion.id)
            let source = sourceLocalizations.first { $0.locale == primaryLocale }
                ?? sourceLocalizations.first
            if let source {
                return AppStoreVersionLocalization.CreateAttributes.copiedMetadata(from: source)
            }
        } catch {
            Self.logger.warning("\(self.t)failed to load source localizations for copy: \(error.localizedDescription)")
        }

        return AppStoreVersionLocalization.CreateAttributes()
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
