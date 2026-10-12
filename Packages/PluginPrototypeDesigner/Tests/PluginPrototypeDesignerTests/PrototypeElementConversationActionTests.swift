import Foundation
import KitHTMLPreview
import KitPrototype
import ProviderConversationInput
import Testing
@testable import PluginPrototypeDesigner

@MainActor
@Suite("Prototype element conversation action")
struct PrototypeElementConversationActionTests {
    @Test("appends the screen HTML file URL without submitting")
    func appendsFileURL() throws {
        let input = DefaultConversationInputProvider()
        input.text = "Make it warmer"
        let resolved = resolvedScreen()

        let outcome = PrototypeElementConversationAction.apply(
            resolved: resolved,
            selectedProjectID: resolved.project.id,
            selectedScreenID: resolved.screen.id,
            input: input
        )

        #expect(outcome == .appended)
        #expect(input.text.contains(resolved.htmlURL.path))
        #expect(input.isSending == false)
    }

    @Test("returns unavailable when no input provider exists")
    func unavailableInput() throws {
        let resolved = resolvedScreen()
        let outcome = PrototypeElementConversationAction.apply(
            resolved: resolved,
            selectedProjectID: resolved.project.id,
            selectedScreenID: resolved.screen.id,
            input: nil
        )

        #expect(outcome == .unavailable)
    }

    @Test("discards stale screen selections")
    func discardsStaleSelection() throws {
        let input = DefaultConversationInputProvider()
        let resolved = resolvedScreen()
        let outcome = PrototypeElementConversationAction.apply(
            resolved: resolved,
            selectedProjectID: resolved.project.id,
            selectedScreenID: "02-other",
            input: input
        )

        #expect(outcome == .staleSelection)
        #expect(input.text.isEmpty)
    }

    private func resolvedScreen() -> PrototypeResolvedScreen {
        let screen = PrototypeScreen(id: "01-home", title: "Home", order: 0)
        let project = PrototypeProject(
            id: "checkout-flow",
            title: "Checkout",
            device: PrototypeDeviceKind.iPhone15Pro.preset!,
            screens: [screen]
        )
        return PrototypeResolvedScreen(
            project: project,
            screen: screen,
            directoryURL: URL(fileURLWithPath: "/workspace/.lumi/prototype/tasks/checkout-flow/01-home"),
            html: "<html></html>"
        )
    }
}
