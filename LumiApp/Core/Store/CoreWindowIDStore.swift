import Foundation
import os

/// Persists main-window IDs so runtime window containers can be re-created
/// with stable identities across app launches.
@MainActor
enum CoreWindowIDStore {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.window-id-store")
    private static let directoryName = "WindowIDs"
    private static let fileName = "window_ids.json"
    private static let corruptFileName = "window_ids.corrupt.json"
    private static let maxWindowCount = 20

    private static var storeDirectoryProvider: () -> URL = {
        AppConfig.getCoreDBFolderURL()
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static var launchWindowIds: [UUID]?
    private static var didConsumeDefaultWindowRoute = false
    private static var didConsumeAdditionalWindowRoutes = false
    private static var pendingWindowRoutes: [LumiWindowRoute] = []

    static func enqueueWindowRoute(_ route: LumiWindowRoute) {
        pendingWindowRoutes.append(route)
    }

    static func consumeNextWindowRoute() -> LumiWindowRoute {
        if !pendingWindowRoutes.isEmpty {
            return pendingWindowRoutes.removeFirst()
        }

        return consumeDefaultWindowRoute() ?? LumiWindowRoute()
    }

    static func consumeRestoredWindowGroupRoute(_ route: LumiWindowRoute?) -> LumiWindowRoute {
        guard let route else {
            return consumeNextWindowRoute()
        }

        let persistedIds = Set(loadLaunchWindowIds())
        guard persistedIds.contains(route.id) else {
            return consumeNextWindowRoute()
        }

        return route
    }

    private static func consumeDefaultWindowRoute() -> LumiWindowRoute? {
        guard !didConsumeDefaultWindowRoute else { return nil }
        didConsumeDefaultWindowRoute = true

        guard let id = loadLaunchWindowIds().first else { return nil }
        return LumiWindowRoute(id: id)
    }

    /// 返回尚未打开的主窗口路由（通常为 `consumeDefaultWindowRoute` 已分配的首个 ID 之外的条目）。
    static func consumeAdditionalWindowRoutes(excluding openIds: Set<UUID> = []) -> [LumiWindowRoute] {
        guard !didConsumeAdditionalWindowRoutes else { return [] }
        didConsumeAdditionalWindowRoutes = true

        return loadLaunchWindowIds()
            .dropFirst()
            .filter { !openIds.contains($0) }
            .map { LumiWindowRoute(id: $0) }
    }

    @discardableResult
    static func saveWindowIds(_ ids: [UUID]) -> Bool {
        let uniqueIds = unique(ids).prefix(maxWindowCount)
        let idsToSave = Array(uniqueIds)
        return persist(idsToSave)
    }

    private static func loadLaunchWindowIds() -> [UUID] {
        if let launchWindowIds {
            return launchWindowIds
        }

        let fileURL = storeFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            launchWindowIds = []
            return []
        }

        let ids: [UUID]
        do {
            let data = try Data(contentsOf: fileURL)
            ids = try JSONDecoder().decode([UUID].self, from: data)
        } catch {
            logger.error("Load window IDs failed: \(error.localizedDescription)")
            quarantineCorruptStore(at: fileURL)
            launchWindowIds = []
            return []
        }

        let loadedIds = Array(unique(ids).prefix(maxWindowCount))
        launchWindowIds = loadedIds
        return loadedIds
    }

    private static func persist(_ ids: [UUID]) -> Bool {
        let data: Data
        do {
            data = try JSONEncoder().encode(ids)
        } catch {
            logger.error("Encode window IDs failed: \(error.localizedDescription)")
            return false
        }

        do {
            try FileManager.default.createDirectory(
                at: storeDirectoryURL(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: storeFileURL(), options: .atomic)
            return true
        } catch {
            logger.error("Persist window IDs failed: \(error.localizedDescription)")
            return false
        }
    }

    private static func unique(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }

    private static func storeDirectoryURL() -> URL {
        storeDirectoryProvider()
    }

    private static func storeFileURL() -> URL {
        storeDirectoryURL()
            .appendingPathComponent(fileName, isDirectory: false)
    }

    private static func corruptStoreFileURL() -> URL {
        storeDirectoryURL()
            .appendingPathComponent(corruptFileName, isDirectory: false)
    }

    private static func quarantineCorruptStore(at fileURL: URL) {
        let quarantineURL = corruptStoreFileURL()
        do {
            if FileManager.default.fileExists(atPath: quarantineURL.path) {
                try FileManager.default.removeItem(at: quarantineURL)
            }
            try FileManager.default.moveItem(at: fileURL, to: quarantineURL)
        } catch {
            logger.error("Quarantine corrupt window IDs failed: \(error.localizedDescription)")
        }
    }

    static func configureForTesting(storeDirectory: URL) {
        storeDirectoryProvider = { storeDirectory }
        launchWindowIds = nil
        didConsumeDefaultWindowRoute = false
        didConsumeAdditionalWindowRoutes = false
        pendingWindowRoutes = []
    }

    static func resetTestingConfiguration() {
        storeDirectoryProvider = {
            AppConfig.getCoreDBFolderURL()
                .appendingPathComponent(directoryName, isDirectory: true)
        }
        launchWindowIds = nil
        didConsumeDefaultWindowRoute = false
        didConsumeAdditionalWindowRoutes = false
        pendingWindowRoutes = []
    }
}
