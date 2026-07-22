import Foundation
import LumiKernel
import LumiKernel
import LumiKernel
import Testing
@testable import ChatPanelPlugin

@MainActor
@Test func chatSectionPluginsReturnEmptyWithoutCoordinator() {
    let kernel = LumiKernel()

    #expect(ChatPendingSectionPlugin().chatSectionItems(kernel: kernel).isEmpty)
    #expect(ChatAttachmentSectionPlugin().chatSectionItems(kernel: kernel).isEmpty)
    #expect(ChatComposerSectionPlugin().chatSectionItems(kernel: kernel).isEmpty)
}

@MainActor
@Test func chatSectionPluginsContributeItemsWithCoordinator() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ChatSectionPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = try ChatService(
        configuration: .coreDatabase(directory: directory),
        agentToolComponent: AgentToolComponent()
    )
    let coordinator = ChatSectionCoordinator(chatService: chatService)

    let kernel = LumiKernel()
    kernel.registerService(ChatSectionCoordinator.self, coordinator)

    #expect(ChatPendingSectionPlugin().chatSectionItems(kernel: kernel).isEmpty)
    #expect(ChatAttachmentSectionPlugin().chatSectionItems(kernel: kernel).count == 1)
    #expect(ChatComposerSectionPlugin().chatSectionItems(kernel: kernel).count == 1)
    #expect(ChatComposerSectionPlugin().chatSectionItems(kernel: kernel).first?.placement == .bottomFixed)
}
