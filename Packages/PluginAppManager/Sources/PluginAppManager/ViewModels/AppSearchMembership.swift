import Foundation

/// Caches App Manager search membership so the expensive localized name/bundle-ID
/// filter only reruns when the query or the searchable fields change — not when a
/// background size calculation republishes `installedApps` (#1220).
///
/// Size-only updates keep the same searchable projection, so the cached match set
/// is reused and the output is rebuilt with cheap path membership lookups instead
/// of repeating N localized string searches per refresh.
final class AppSearchMembership: @unchecked Sendable {
    struct Key: Equatable {
        let path: String
        let displayName: String
        let bundleIdentifier: String?
    }

    private var lastQuery: String?
    private var lastKeys: [Key] = []
    /// `nil` means the query is empty (every app matches).
    private var matchPaths: Set<String>?
    private(set) var recomputeCount = 0

    func filtered(query: String, apps: [AppModel]) -> [AppModel] {
        let keys = apps.map {
            Key(path: $0.bundleURL.path, displayName: $0.displayName, bundleIdentifier: $0.bundleIdentifier)
        }
        if query != lastQuery || keys != lastKeys {
            lastQuery = query
            lastKeys = keys
            recomputeCount += 1
            if query.isEmpty {
                matchPaths = nil
            } else {
                matchPaths = Set(apps.filter { app in
                    app.displayName.localizedCaseInsensitiveContains(query) ||
                    (app.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
                }.map { $0.bundleURL.path })
            }
        }
        guard let matchPaths else { return apps }
        return apps.filter { matchPaths.contains($0.bundleURL.path) }
    }
}