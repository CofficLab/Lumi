import Foundation
import Testing
@testable import ProviderWorkspace

@Suite("ProviderWorkspace") @MainActor
struct ProviderWorkspaceTests {
    @Test func policiesAndOverrides() {
        let provider = DefaultWorkspaceProviding(pluginDirectory: temporaryDirectory())
        provider.registerContainer(.init(id: "chat", title: "Chat", systemImage: "bubble.left",
            chatVisibility: .alwaysVisible, panelBodyVisibility: .unsupported), ownerPluginID: "plugin.chat")
        #expect(provider.activeContainerID == "chat")
        #expect(provider.isChatVisible)
        #expect(!provider.isPanelBodyVisible)
        provider.setRailVisible(false); provider.setChatVisible(false)
        #expect(!provider.isRailVisible)
        #expect(provider.isChatVisible)
        #expect(provider.visibilityOverrides(for: "chat")?.rail == false)
        #expect(provider.visibilityOverrides(for: "chat")?.chat == nil)
    }

    @Test func ownerWithdrawalSelectsFallback() {
        let provider = DefaultWorkspaceProviding(pluginDirectory: temporaryDirectory())
        provider.registerContainer(.init(id: "a", title: "A", systemImage: "a", order: 1), ownerPluginID: "one")
        provider.registerContainer(.init(id: "b", title: "B", systemImage: "b", order: 2), ownerPluginID: "two")
        provider.unregisterContainers(ownerPluginID: "one")
        #expect(provider.containers.map(\.id) == ["b"])
        #expect(provider.activeContainerID == "b")
    }

    @Test func persistenceRoundTrip() throws {
        let directory = temporaryDirectory()
        var provider: DefaultWorkspaceProviding? = DefaultWorkspaceProviding(pluginDirectory: directory)
        provider?.registerContainer(.init(id: "chat", title: "Chat", systemImage: "bubble.left"), ownerPluginID: "chat")
        provider?.setRailVisible(false); provider?.presentRailTab(id: "history", for: "chat")
        provider?.setChatDivider(456, for: "chat", layout: .wide); try provider?.save(); provider = nil
        let restored = DefaultWorkspaceProviding(pluginDirectory: directory)
        restored.registerContainer(.init(id: "chat", title: "Chat", systemImage: "bubble.left"), ownerPluginID: "chat")
        #expect(restored.activeContainerID == "chat")
        #expect(!restored.isRailVisible)
        #expect(restored.activeRailTabID(for: "chat") == "history")
        #expect(restored.chatDivider(for: "chat", layout: .wide, fallback: 320) == 456)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ProviderWorkspaceTests-\(UUID().uuidString)")
    }
}
