import Foundation

/// Persists main-window IDs so runtime window containers can be re-created
/// with stable identities across app launches.
@MainActor
enum CoreWindowIDStore {
    private static let directoryName = "WindowIDs"
    private static let fileName = "window_ids.json"
    private static let maxWindowCount = 20

    private static var launchWindowIds: [UUID]?
    private static var didConsumeDefaultWindowRoute = false
    private static var didConsumeAdditionalWindowRoutes = false

    static func consumeDefaultWindowRoute() -> LumiWindowRoute? {
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

    static func saveWindowIds(_ ids: [UUID]) {
        let uniqueIds = unique(ids).prefix(maxWindowCount)
        let idsToSave = Array(uniqueIds)
        persist(idsToSave)
    }

    private static func loadLaunchWindowIds() -> [UUID] {
        if let launchWindowIds {
            return launchWindowIds
        }

        let fileURL = storeFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            launchWindowIds = []
            return []
        }

        let loadedIds = Array(unique(ids).prefix(maxWindowCount))
        launchWindowIds = loadedIds
        return loadedIds
    }

    private static func persist(_ ids: [UUID]) {
        guard let data = try? JSONEncoder().encode(ids) else { return }

        do {
            try FileManager.default.createDirectory(
                at: storeDirectoryURL(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: storeFileURL(), options: .atomic)
        } catch {
            // Window identity persistence is best-effort and non-critical.
        }
    }

    private static func unique(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }

    private static func storeDirectoryURL() -> URL {
        AppConfig.getCoreDBFolderURL()
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func storeFileURL() -> URL {
        storeDirectoryURL()
            .appendingPathComponent(fileName, isDirectory: false)
    }
}
