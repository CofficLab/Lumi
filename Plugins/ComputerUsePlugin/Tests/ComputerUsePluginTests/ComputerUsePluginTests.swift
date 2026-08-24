import CoreGraphics
import Foundation
import KernelLumi
import Testing
@testable import ComputerUsePlugin

@Suite("ComputerUsePlugin")
struct ComputerUsePluginTests {
    @MainActor
    @Test("plugin is always on and contributes both tools")
    func pluginContributions() {
        let plugin = ComputerUseSuperPlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.computer-use")
        #expect(plugin.metadata.policy == .alwaysOn)
        #expect(ComputerObserveV2Tool().name == "computer_observe")
        #expect(ComputerActV2Tool().name == "computer_act")
        #expect(ComputerActV2Tool().inputSchema(for: .english)["required"] as? [String] == ["observation_id", "actions"])
    }

    @Test("action parser accepts a complete batch")
    func parsesActions() throws {
        let actions = try ComputerUseActionParser.parse(.array([
            .object(["type": .string("click"), "x": .int(20), "y": .double(30.5)]),
            .object(["type": .string("type"), "text": .string("hello")]),
            .object(["type": .string("keypress"), "keys": .array([.string("CMD"), .string("A")])]),
            .object(["type": .string("wait"), "milliseconds": .int(99_999)]),
        ]))
        #expect(actions.count == 4)
        #expect(actions[0] == .click(x: 20, y: 30.5, button: .left, count: 1))
        #expect(actions[1] == .type("hello"))
        #expect(actions[2] == .keypress(["CMD", "A"]))
        #expect(actions[3] == .wait(milliseconds: 10_000))
    }

    @Test("action parser rejects unsafe batches")
    func rejectsInvalidActions() {
        #expect(throws: ComputerUseError.self) {
            try ComputerUseActionParser.parse(.array([]))
        }
        #expect(throws: ComputerUseError.self) {
            try ComputerUseActionParser.parse(.array([
                .object(["type": .string("click"), "x": .int(-1), "y": .int(2)]),
            ]))
        }
        #expect(throws: ComputerUseError.self) {
            try ComputerUseActionParser.parse(.array([
                .object(["type": .string("unknown")]),
            ]))
        }
    }

    @Test("observation maps delivered image coordinates to the target window")
    func coordinateMapping() {
        let observation = ComputerUseObservation(
            window: window(id: 1, bundleIdentifier: "example", name: "Example", title: "Main", frame: CGRect(x: 100, y: 50, width: 800, height: 600)),
            imageWidth: 1_600,
            imageHeight: 1_200
        )
        #expect(observation.screenPoint(imageX: 800, imageY: 600) == CGPoint(x: 500, y: 350))
    }

    @Test("window selection prefers the frontmost app when no query is supplied")
    func selectsFrontmostWindow() {
        let windows = [
            window(id: 1, bundleIdentifier: "first.app", name: "First", title: "One"),
            window(id: 2, bundleIdentifier: "front.app", name: "Front", title: "Two"),
        ]
        let selected = ComputerUseWindowProvider.select(
            from: windows,
            application: nil,
            windowTitle: nil,
            frontmostBundleIdentifier: "front.app"
        )
        #expect(selected?.id == 2)
    }

    @Test("window selection supports application and title queries")
    func selectsQueriedWindow() {
        let windows = [
            window(id: 1, bundleIdentifier: "com.example.editor", name: "Editor", title: "README"),
            window(id: 2, bundleIdentifier: "com.example.editor", name: "Editor", title: "Package.swift"),
        ]
        let selected = ComputerUseWindowProvider.select(
            from: windows,
            application: "com.example.editor",
            windowTitle: "package",
            frontmostBundleIdentifier: nil
        )
        #expect(selected?.id == 2)
    }

    @Test("authorization store persists an explicit allow list")
    func authorizationStore() throws {
        let suiteName = "ComputerUsePluginTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ComputerUseAuthorizationStore(defaults: defaults)
        #expect(!store.isAllowed("com.example.app"))
        store.setAllowed(true, bundleIdentifier: "com.example.app")
        #expect(store.isAllowed("com.example.app"))
        store.setAllowed(false, bundleIdentifier: "com.example.app")
        #expect(!store.isAllowed("com.example.app"))
    }

    private func window(
        id: CGWindowID,
        bundleIdentifier: String,
        name: String,
        title: String,
        frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600)
    ) -> ComputerUseWindow {
        ComputerUseWindow(
            id: id,
            processIdentifier: 123,
            bundleIdentifier: bundleIdentifier,
            applicationName: name,
            windowTitle: title,
            frame: frame
        )
    }
}
