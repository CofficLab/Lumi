import Foundation
import SuperLogKit

extension VM {
    func loadApps(silent: Bool = false) async {
        if silent {
            do {
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                apps = try await client.listApps(search: query.isEmpty ? nil : query)
                connectionStatus = AppStoreConnectLocalization.string("Connected")
                applyPersistedOrDefaultSelectedApp()
            } catch {
                Self.logger.error("\(Self.t)loadApps(silent) failed: \(error.localizedDescription)")
            }
        } else {
            await runBusy {
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                apps = try await client.listApps(search: query.isEmpty ? nil : query)
                connectionStatus = AppStoreConnectLocalization.string("Connected")
                applyPersistedOrDefaultSelectedApp()
            }
        }
    }

    func selectApp(_ app: AppStoreApp, openDistribution: Bool = false) {
        let appChanged = selectedApp?.id != app.id
        selectedApp = app
        localStore.setSelectedAppID(app.id, for: credentials)
        if appChanged {
            selectedVersion = nil
            if page == .coverArt {
                page = .distribution
            }
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
        reloadCoverArtList()
    }

    func applyPersistedOrDefaultSelectedApp() {
        let target: AppStoreApp?
        if let persistedID = localStore.selectedAppID(for: credentials),
           let persisted = apps.first(where: { $0.id == persistedID }) {
            target = persisted
        } else if let current = selectedApp,
                  apps.contains(where: { $0.id == current.id }) {
            target = current
        } else {
            target = apps.first
        }

        guard let target else {
            selectedApp = nil
            return
        }

        if selectedApp?.id != target.id {
            selectApp(target, openDistribution: false)
        }
    }
}
