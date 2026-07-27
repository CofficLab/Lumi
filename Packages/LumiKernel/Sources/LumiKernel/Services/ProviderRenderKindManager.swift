import Foundation

public protocol ProviderRenderKindManaging: Sendable {
    func registerProviderPrefix(_ prefix: String, for providerId: String)
    func unregisterProviderPrefix(for providerId: String)
    func isProviderSpecificRenderKind(_ renderKind: String?) -> Bool
    func isRenderKind(_ renderKind: String?, ownedBy providerId: String) -> Bool
    func providerPrefix(for providerId: String) -> String?
    func allProviderPrefixes() -> Set<String>
    func allProviderIds() -> Set<String>
}

public final class ProviderRenderKindManager: ProviderRenderKindManaging, @unchecked Sendable {
    public static let shared = ProviderRenderKindManager()
    private var prefixByProvider: [String: String] = [:]
    private var providerByPrefix: [String: String] = [:]
    private let lock = NSLock()
    private init() {}

    public func registerProviderPrefix(_ prefix: String, for providerId: String) {
        lock.lock()
        defer { lock.unlock() }
        if let oldPrefix = prefixByProvider[providerId] {
            providerByPrefix.removeValue(forKey: oldPrefix)
        }
        prefixByProvider[providerId] = prefix
        providerByPrefix[prefix] = providerId
    }

    public func unregisterProviderPrefix(for providerId: String) {
        lock.lock()
        defer { lock.unlock() }
        if let prefix = prefixByProvider[providerId] {
            providerByPrefix.removeValue(forKey: prefix)
            prefixByProvider.removeValue(forKey: providerId)
        }
    }

    public func isProviderSpecificRenderKind(_ renderKind: String?) -> Bool {
        guard let renderKind else { return false }
        lock.lock()
        defer { lock.unlock() }
        return providerByPrefix.keys.contains { prefix in renderKind.hasPrefix(prefix) }
    }

    public func isRenderKind(_ renderKind: String?, ownedBy providerId: String) -> Bool {
        guard let renderKind else { return false }
        lock.lock()
        defer { lock.unlock() }
        guard let prefix = prefixByProvider[providerId] else { return false }
        return renderKind.hasPrefix(prefix)
    }

    public func providerPrefix(for providerId: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return prefixByProvider[providerId]
    }

    public func allProviderPrefixes() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(providerByPrefix.keys)
    }

    public func allProviderIds() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(prefixByProvider.keys)
    }
}
