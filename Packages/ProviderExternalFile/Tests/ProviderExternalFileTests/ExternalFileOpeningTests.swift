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

    @Test("open returns false when no handler is registered")
    func openReturnsFalseWithNoHandlers() {
        let provider = DefaultExternalFileOpening()
        #expect(!provider.open(URL(fileURLWithPath: "/tmp/anything.txt")))
    }

    @Test("open returns false when every handler declines the file")
    func openReturnsFalseWhenAllHandlersDecline() {
        let provider = DefaultExternalFileOpening()
        provider.registerHandler(pluginID: "a") { _ in false }
        provider.registerHandler(pluginID: "b") { _ in false }
        #expect(!provider.open(URL(fileURLWithPath: "/tmp/file")))
    }

    @Test("a plugin with multiple handlers tries them in registration order")
    func multipleHandlersPerPluginAreTriedInOrder() {
        let provider = DefaultExternalFileOpening()
        var calls: [String] = []
        provider.registerHandler(pluginID: "plugin") { _ in calls.append("h1"); return false }
        provider.registerHandler(pluginID: "plugin") { _ in calls.append("h2"); return false }
        provider.registerHandler(pluginID: "plugin") { _ in calls.append("h3"); return true }

        #expect(provider.open(URL(fileURLWithPath: "/tmp/file")))
        #expect(calls == ["h1", "h2", "h3"])
    }

    @Test("within a plugin, a handling handler stops further dispatch")
    func handlingHandlerStopsWithinPlugin() {
        let provider = DefaultExternalFileOpening()
        var calls: [String] = []
        provider.registerHandler(pluginID: "plugin") { _ in calls.append("h1"); return true }
        provider.registerHandler(pluginID: "plugin") { _ in calls.append("h2"); return false }

        #expect(provider.open(URL(fileURLWithPath: "/tmp/file")))
        #expect(calls == ["h1"])
    }

    @Test("unregistering an unknown plugin is a no-op")
    func unregisterUnknownPluginIsNoOp() {
        let provider = DefaultExternalFileOpening()
        provider.registerHandler(pluginID: "real") { _ in true }
        provider.unregisterHandlers(pluginID: "missing")
        #expect(provider.open(URL(fileURLWithPath: "/tmp/file")))
    }

    @Test("re-registering after unregister moves the plugin to the end of dispatch order")
    func reregisterAfterUnregisterGoesLast() {
        let provider = DefaultExternalFileOpening()
        var calls: [String] = []
        provider.registerHandler(pluginID: "first") { _ in calls.append("first"); return false }
        provider.registerHandler(pluginID: "second") { _ in calls.append("second"); return false }

        // Remove and re-register "first"; it should now dispatch after "second".
        provider.unregisterHandlers(pluginID: "first")
        provider.registerHandler(pluginID: "first") { _ in calls.append("first-rereg"); return false }

        provider.open(URL(fileURLWithPath: "/tmp/file"))
        #expect(calls == ["second", "first-rereg"])
    }

    @Test("handlers receive the standardized, symlink-resolved URL")
    func handlersReceiveStandardizedURL() {
        let provider = DefaultExternalFileOpening()
        var received: URL?
        provider.registerHandler(pluginID: "p") { url in received = url; return true }

        // Use a path with a trailing slash / redundant component to exercise standardization.
        let raw = URL(fileURLWithPath: "/tmp/./demo.sqlite")
        provider.open(raw)

        #expect(received == raw.standardizedFileURL.resolvingSymlinksInPath())
    }

    @Test("handlers can inspect the URL they were given")
    func handlersReceiveRequestedURL() {
        let provider = DefaultExternalFileOpening()
        var seenPath: String?
        provider.registerHandler(pluginID: "ext") { url in
            seenPath = url.path
            return true
        }
        provider.open(URL(fileURLWithPath: "/tmp/project.demo"))
        #expect(seenPath == "/tmp/project.demo")
    }
}
