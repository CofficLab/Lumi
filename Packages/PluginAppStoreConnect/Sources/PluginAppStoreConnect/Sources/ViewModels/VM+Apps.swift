import Foundation
import LumiLoggingKit
extension VM {
    func loadApps(silent: Bool = false) async {
        guard !isLoadingApps else { return }
        isLoadingApps = true
        defer { isLoadingApps = false }

        if silent {
            do {
                try await reloadAppsFromNetwork()
            } catch {
                Self.logger.error("\(Self.t)loadApps(silent) failed: \(error.localizedDescription)")
            }
        } else {
            await runBusy {
                try await reloadAppsFromNetwork()
            }
        }
    }

    func reloadAppsFromNetwork() async throws {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        // 请求期间用户可能切换账号或断开连接，结果必须能判定归属。
        let requestedCredentials = credentials
        let loaded = try await client.listApps(search: query.isEmpty ? nil : query)
        applyLoadedApps(loaded, for: requestedCredentials)
    }

    /// 写入 App 列表前校验账号身份，返回是否真的写入。
    @discardableResult
    func applyLoadedApps(
        _ loaded: [AppStoreApp],
        for requestedCredentials: AppStoreConnectCredentials
    ) -> Bool {
        guard credentials == requestedCredentials else { return false }
        apps = loaded
        connectionStatus = AppStoreConnectLocalization.string("Connected")
        applyPersistedOrDefaultSelectedApp()
        return true
    }

    func selectApp(_ app: AppStoreApp, openDistribution: Bool = false) {
        let appChanged = selectedApp?.id != app.id
        selectedApp = app
        localStore.setSelectedAppID(app.id, for: credentials)
        if appChanged {
            selectionGeneration += 1
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
