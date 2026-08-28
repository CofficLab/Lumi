import Foundation
import ProviderExternalFile
import Testing

@MainActor
struct ExternalFileOpeningTests {
    @Test("dispatches in registration order and stops after handling")
    func dispatchesInOrder() {
        let provider = DefaultExternalFileOpening()
        var calls: [String] = []
        provider.registerHandler(pluginID: "first") { _ in calls.append("first"); return false }
        provider.registerHandler(pluginID: "second") { _ in calls.append("second"); return true }
        provider.registerHandler(pluginID: "third") { _ in calls.append("third"); return true }

        #expect(provider.open(URL(fileURLWithPath: "/tmp/demo.sqlite")))
        #expect(calls == ["first", "second"])
    }

    @Test("unregistering a plugin removes every handler")
    func unregistersPlugin() {
        let provider = DefaultExternalFileOpening()
        provider.registerHandler(pluginID: "database") { _ in true }
        provider.unregisterHandlers(pluginID: "database")

        #expect(!provider.open(URL(fileURLWithPath: "/tmp/demo.sqlite")))
    }
}
