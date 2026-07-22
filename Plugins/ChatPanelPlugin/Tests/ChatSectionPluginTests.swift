import Foundation
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
