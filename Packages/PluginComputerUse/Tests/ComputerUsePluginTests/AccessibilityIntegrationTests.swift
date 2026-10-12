import AppKit
import ApplicationServices
import Foundation
import Testing
@testable import ComputerUsePlugin

@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["LUMI_AX_FIXTURE"] != nil))
func accessibilityOperatesBackgroundFixtureWithoutMovingCursorOrActivatingIt() async throws {
    #expect(AXIsProcessTrusted())
    let executable = try #require(ProcessInfo.processInfo.environment["LUMI_AX_FIXTURE"])
    let fixture = Process()
    fixture.executableURL = URL(fileURLWithPath: executable)
    try fixture.run()
    defer { if fixture.isRunning { fixture.terminate() } }
    let suite = "ComputerUse.AXFixture.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = ComputerUseAuthorizationStore(defaults: defaults)
    store.setAllowed(true, bundleIdentifier: "com.coffic.lumi.tests.axfixture")
    let service = AccessibilityService(authorization: store)
    var observed: String?
    var diagnostic = "No observation"
    for _ in 0..<40 {
        try await Task.sleep(for: .milliseconds(100))
        do {
            let text = try service.observe(application: "com.coffic.lumi.tests.axfixture")
            diagnostic = text
            if text.contains("Fixture Toggle") { observed = text; break }
        } catch { diagnostic = error.localizedDescription }
    }
    if observed == nil {
        let root = AXUIElementCreateApplication(fixture.processIdentifier)
        var windows: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(root, kAXWindowsAttribute as CFString, &windows)
        diagnostic += " windows=\(String(describing: windows)) error=\(result.rawValue)"
    }
    let json = try #require(observed, "\(diagnostic)")
    #expect(!json.contains("fixture-secret-not-for-model"))
    let snapshot = try JSONDecoder().decode(AccessibilityService.Snapshot.self, from: Data(json.utf8))
    let toggle = try #require(snapshot.elements.first { $0.label == "Fixture Toggle" })
    let cursor = CGEvent(source: nil)?.location
    let foreground = NSWorkspace.shared.frontmostApplication?.processIdentifier
    let output = try service.act(observationID: snapshot.observationID, elementID: toggle.id, action: "AXPress", value: nil)
    #expect(output.contains("action_dispatched"))
    #expect(CGEvent(source: nil)?.location == cursor)
    #expect(NSWorkspace.shared.frontmostApplication?.processIdentifier == foreground)
    #expect(throws: (any Error).self) {
        try service.act(observationID: snapshot.observationID, elementID: toggle.id, action: "AXPress", value: nil)
    }
    let afterJSON = try service.observe(application: "com.coffic.lumi.tests.axfixture")
    let after = try JSONDecoder().decode(AccessibilityService.Snapshot.self, from: Data(afterJSON.utf8))
    #expect(after.elements.first { $0.label == "Fixture Toggle" }?.value != toggle.value)
    let text = try #require(after.elements.first { $0.label == "Fixture Text" })
    #expect(text.valueSettable)
    _ = try service.act(observationID: after.observationID, elementID: text.id, action: "set_value", value: "updated by AX")
    let finalJSON = try service.observe(application: "com.coffic.lumi.tests.axfixture")
    #expect(finalJSON.contains("updated by AX"))
    #expect(!finalJSON.contains("fixture-secret-not-for-model"))
    #expect(NSWorkspace.shared.frontmostApplication?.processIdentifier == foreground)
}
