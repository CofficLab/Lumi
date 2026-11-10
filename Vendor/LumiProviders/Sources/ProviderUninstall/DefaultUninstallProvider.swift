import Foundation
import Security

public struct DefaultUninstallPersistentDomainRemover: UninstallPersistentDomainRemoving {
    public init() {}

    public func removePersistentDomain(named name: String) throws {
        UserDefaults.standard.removePersistentDomain(forName: name)
        UserDefaults.standard.synchronize()
    }
}

public struct DefaultUninstallKeychainManager: UninstallKeychainManaging {
    public init() {}

    public func containsItems(forService service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess
    }

    public func removeItems(forService service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Keychain 删除失败（(status)）"
            ])
        }
    }
}

/// Default Lumi uninstall implementation.
///
/// The provider intentionally uses exact names and boundary checks. It never
/// performs a fuzzy scan such as deleting every directory containing "Lumi".
public final class DefaultUninstallProvider: UninstallProviding, @unchecked Sendable {
    private let locations: UninstallLocations
    private let scope: UninstallScope
    private let persistentDomainRemover: any UninstallPersistentDomainRemoving
    private let keychainManager: any UninstallKeychainManaging
    private let fileManager: FileManager

    public init(
        locations: UninstallLocations = .live(),
        scope: UninstallScope = .live(),
        persistentDomainRemover: any UninstallPersistentDomainRemoving = DefaultUninstallPersistentDomainRemover(),
        keychainManager: any UninstallKeychainManaging = DefaultUninstallKeychainManager(),
        fileManager: FileManager = .default
    ) {
        self.locations = locations
        self.scope = scope
        self.persistentDomainRemover = persistentDomainRemover
        self.keychainManager = keychainManager
        self.fileManager = fileManager
    }

    public func scan() async -> UninstallScan {
        UninstallScan(targets: makeTargets(includeOnlyExisting: true))
    }

    public func uninstall(options: UninstallOptions) async throws -> UninstallResult {
        guard options.confirmation == UninstallOptions.confirmationPhrase else {
            throw UninstallError.invalidConfirmation
        }

        let targets = makeTargets(includeOnlyExisting: true)
        var removedTargetIDs: [String] = []
        var failures: [UninstallFailure] = []

        for target in targets where shouldRemove(target, options: options) {
            do {
                try validateTarget(target)
                try remove(target)
                removedTargetIDs.append(target.id)
            } catch {
                failures.append(UninstallFailure(
                    targetID: target.id,
                    location: target.location,
                    message: error.localizedDescription
                ))
            }
        }

        // Do not remove the app if any Lumi-owned data could not be cleaned.
        // This avoids claiming a complete uninstall while leaving data behind.
        var applicationMovedToTrash = false
        if options.removeApplication,
           failures.isEmpty,
           let applicationTarget = targets.first(where: { $0.kind == .application }) {
            do {
                try validateTarget(applicationTarget)
                guard let applicationURL = locations.applicationBundleURL else {
                    throw UninstallError.unsafeTarget(applicationTarget.location)
                }
                try fileManager.trashItem(at: applicationURL, resultingItemURL: nil)
                removedTargetIDs.append(applicationTarget.id)
                applicationMovedToTrash = true
            } catch {
                failures.append(UninstallFailure(
                    targetID: applicationTarget.id,
                    location: applicationTarget.location,
                    message: error.localizedDescription
                ))
            }
        }

        return UninstallResult(
            removedTargetIDs: removedTargetIDs,
            failures: failures,
            applicationMovedToTrash: applicationMovedToTrash
        )
    }

    // MARK: - Target discovery

    private func makeTargets(includeOnlyExisting: Bool) -> [UninstallTarget] {
        var targets: [UninstallTarget] = []
        var seenIDs = Set<String>()

        func append(_ target: UninstallTarget, exists: Bool = true) {
            guard (!includeOnlyExisting || exists), seenIDs.insert(target.id).inserted else { return }
            targets.append(target)
        }

        func appendPath(id: String, url: URL, kind: UninstallTargetKind) {
            append(
                pathTarget(id: id, url: url, kind: kind),
                exists: fileManager.fileExists(atPath: url.path)
            )
        }

        let appSupport = locations.applicationSupportDirectory
        for bundleID in scope.bundleIdentifiers {
            let url = appSupport.appendingPathComponent(bundleID, isDirectory: true)
            appendPath(
                id: "application-support.\(bundleID)",
                url: url,
                kind: bundleID == "com.coffic.Lumi" ? .legacyData : .applicationData
            )
        }

        let legacySupportPaths = scope.legacyApplicationSupportDirectories.map {
            ("application-support.\($0)", $0)
        }
        for (id, name) in legacySupportPaths {
            let url = appSupport.appendingPathComponent(name, isDirectory: true)
            appendPath(id: id, url: url, kind: .legacyData)
        }

        for bundleID in scope.cacheBundleIdentifiers {
            let cacheURL = locations.cachesDirectory.appendingPathComponent(bundleID, isDirectory: true)
            appendPath(id: "cache.\(bundleID)", url: cacheURL, kind: .caches)

            let webKitURL = locations.webKitDirectory.appendingPathComponent(bundleID, isDirectory: true)
            appendPath(id: "webkit.\(bundleID)", url: webKitURL, kind: .caches)

            let containerURL = locations.containersDirectory.appendingPathComponent(bundleID, isDirectory: true)
            appendPath(id: "container.\(bundleID)", url: containerURL, kind: .caches)

            let savedStateURL = locations.savedApplicationStateDirectory
                .appendingPathComponent("\(bundleID).savedState", isDirectory: true)
            appendPath(id: "saved-state.\(bundleID)", url: savedStateURL, kind: .caches)

            let cookieURL = locations.cookiesDirectory
                .appendingPathComponent("\(bundleID).binarycookies", isDirectory: false)
            appendPath(id: "cookie.\(bundleID)", url: cookieURL, kind: .caches)
        }

        for groupID in scope.appGroupIdentifiers {
            let url = locations.groupContainersDirectory.appendingPathComponent(groupID, isDirectory: true)
            appendPath(id: "app-group.\(groupID)", url: url, kind: .appGroup)
        }

        for domain in scope.preferenceDomains {
            let url = locations.preferencesDirectory.appendingPathComponent("\(domain).plist", isDirectory: false)
            let exists = fileManager.fileExists(atPath: url.path)
                || persistentDomainHasValues(domain)
            append(UninstallTarget(
                id: "preferences.\(domain)",
                kind: .preferences,
                location: url.path,
                sizeInBytes: fileSize(of: url),
                isSensitive: true
            ), exists: exists)
        }

        for service in scope.keychainServices where keychainManager.containsItems(forService: service) {
            append(UninstallTarget(
                id: "keychain.\(service)",
                kind: .keychain,
                location: "Keychain service \(service)",
                isSensitive: true
            ))
        }

        if let applicationURL = locations.applicationBundleURL {
            appendPath(id: "application", url: applicationURL, kind: .application)
        }

        return targets.sorted { $0.kind.rawValue == $1.kind.rawValue ? $0.location < $1.location : $0.kind.rawValue < $1.kind.rawValue }
    }

    private func pathTarget(id: String, url: URL, kind: UninstallTargetKind) -> UninstallTarget {
        UninstallTarget(
            id: id,
            kind: kind,
            location: url.path,
            sizeInBytes: fileSize(of: url),
            isSensitive: kind != .application
        )
    }

    private func persistentDomainHasValues(_ domain: String) -> Bool {
        !(UserDefaults.standard.persistentDomain(forName: domain)?.isEmpty ?? true)
    }

    private func fileSize(of url: URL) -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else { return 0 }
        if let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]),
           let size = values.totalFileAllocatedSize ?? values.fileSize {
            return Int64(size)
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return enumerator.reduce(into: Int64(0)) { result, item in
            guard let childURL = item as? URL,
                  let values = try? childURL.resourceValues(forKeys: [.fileSizeKey]),
                  let size = values.fileSize else { return }
            result += Int64(size)
        }
    }

    // MARK: - Removal

    private func shouldRemove(_ target: UninstallTarget, options: UninstallOptions) -> Bool {
        if target.kind == .application { return false }
        if target.kind == .keychain { return options.removeKeychainCredentials }
        return true
    }

    private func validateTarget(_ target: UninstallTarget) throws {
        if target.kind == .keychain || target.kind == .preferences {
            return
        }

        guard let url = url(for: target), isAllowed(url: url, kind: target.kind) else {
            throw UninstallError.unsafeTarget(target.location)
        }
    }

    private func url(for target: UninstallTarget) -> URL? {
        if target.kind == .application {
            return locations.applicationBundleURL
        }
        return URL(fileURLWithPath: target.location, isDirectory: target.kind != .caches)
    }

    private func isAllowed(url: URL, kind: UninstallTargetKind) -> Bool {
        let target = url.standardizedFileURL
        let roots: [URL]
        switch kind {
        case .applicationData, .legacyData:
            roots = [locations.applicationSupportDirectory]
        case .caches:
            roots = [
                locations.cachesDirectory,
                locations.savedApplicationStateDirectory,
                locations.webKitDirectory,
                locations.containersDirectory,
                locations.cookiesDirectory
            ]
        case .appGroup:
            roots = [locations.groupContainersDirectory]
        case .application:
            guard target.pathExtension == "app" else { return false }
            roots = locations.applicationBundleURL.map { [$0.deletingLastPathComponent()] } ?? []
        case .preferences, .keychain:
            roots = []
        }
        return roots.contains { root in
            let normalizedRoot = root.standardizedFileURL
            return target == normalizedRoot || target.path.hasPrefix(normalizedRoot.path + "/")
        }
    }

    private func remove(_ target: UninstallTarget) throws {
        switch target.kind {
        case .keychain:
            let service = target.id.replacingOccurrences(of: "keychain.", with: "")
            try keychainManager.removeItems(forService: service)
        case .preferences:
            let domain = target.id.replacingOccurrences(of: "preferences.", with: "")
            try persistentDomainRemover.removePersistentDomain(named: domain)
            let preferenceURL = locations.preferencesDirectory.appendingPathComponent("\(domain).plist")
            if fileManager.fileExists(atPath: preferenceURL.path) {
                try validateTarget(target)
                try fileManager.removeItem(at: preferenceURL)
            }
        case .application:
            break
        default:
            guard let url = url(for: target) else {
                throw UninstallError.unsafeTarget(target.location)
            }
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }
}
