import Foundation
import Testing
@testable import ComputerUsePlugin

@Test func authorizationStoreAddsRemovesAndIgnoresEmptyIdentifiers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ComputerUseAuthStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ComputerUseAuthorizationStore(dataDirectory: directory)

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

@Test func revokingExplicitAuthorizationAlsoRevokesNativeAuthorization() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ComputerUseAuthStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ComputerUseAuthorizationStore(dataDirectory: directory)

    store.setNativeAllowed(true, bundleIdentifier: "com.example.editor")
    #expect(store.isNativeAllowed("com.example.editor"))

    store.setAllowed(false, bundleIdentifier: "com.example.editor")
    #expect(!store.isNativeAllowed("com.example.editor"))
}

@Test func authorizationStorePersistsAcrossInstances() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ComputerUseAuthStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = ComputerUseAuthorizationStore(dataDirectory: directory)
    store.setNativeAllowed(true, bundleIdentifier: "com.example.editor")

    let reloaded = ComputerUseAuthorizationStore(dataDirectory: directory)
    #expect(reloaded.isNativeAllowed("com.example.editor"))
}

