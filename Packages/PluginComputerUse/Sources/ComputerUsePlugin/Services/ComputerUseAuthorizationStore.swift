import Foundation

final class ComputerUseAuthorizationStore: @unchecked Sendable {
    static let shared = ComputerUseAuthorizationStore()

    private let defaults: UserDefaults
    private let lock = NSLock()
    private let key = "ComputerUse.alwaysAllowedBundleIdentifiers"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func allowedBundleIdentifiers() -> Set<String> {
        lock.withLock {
            Set(defaults.stringArray(forKey: key) ?? [])
        }
    }

    func isAllowed(_ bundleIdentifier: String) -> Bool {
        allowedBundleIdentifiers().contains(bundleIdentifier)
    }

    func setAllowed(_ allowed: Bool, bundleIdentifier: String) {
        guard !bundleIdentifier.isEmpty else { return }
        lock.withLock {
            var values = Set(defaults.stringArray(forKey: key) ?? [])
            if allowed {
                values.insert(bundleIdentifier)
            } else {
                values.remove(bundleIdentifier)
            }
            defaults.set(values.sorted(), forKey: key)
        }
    }
}
