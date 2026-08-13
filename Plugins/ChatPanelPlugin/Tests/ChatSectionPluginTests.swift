import Foundation
import KernelLumi
import Testing
@testable import ChatPanelPlugin

@MainActor
@Test func chatSectionPluginsReturnEmptyWithoutCoordinator() {
    let kernel = KernelLumi()

    #expect(ChatPendingSectionPlugin().chatSectionItems(kernel: kernel).isEmpty)
    #expect(ChatAttachmentSectionPlugin().chatSectionItems(kernel: kernel).isEmpty)
    #expect(ChatComposerSectionPlugin().chatSectionItems(kernel: kernel).isEmpty)
}
