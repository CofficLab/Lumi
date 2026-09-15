import Foundation
import Testing
@testable import ComputerUsePlugin

@Test func authorizationStoreAddsRemovesAndIgnoresEmptyIdentifiers() {
    let suiteName = "PluginComputerUseTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = ComputerUseAuthorizationStore(defaults: defaults)

    #expect(store.allowedBundleIdentifiers().isEmpty)
    store.setAllowed(true, bundleIdentifier: "com.example.editor")
    store.setAllowed(true, bundleIdentifier: "com.example.browser")
    store.setAllowed(true, bundleIdentifier: "com.example.editor")
    #expect(store.allowedBundleIdentifiers() == ["com.example.editor", "com.example.browser"])
    #expect(store.isAllowed("com.example.editor"))

    store.setAllowed(false, bundleIdentifier: "com.example.editor")
    store.setAllowed(true, bundleIdentifier: "")
    #expect(store.allowedBundleIdentifiers() == ["com.example.browser"])
    #expect(!store.isAllowed("com.example.editor"))
}
