import Foundation
import LumiKernel

final class PreviewLumiCoreStub: LumiCoreAccessing {
    let storage = StorageComponent(dataRootDirectory: URL(fileURLWithPath: "/tmp/preview"))
    let logoComponent = LogoComponent()
    let projectComponent = ProjectComponent()
    let layoutComponent = LayoutComponent(state: LayoutState())
    let chatService: any LumiChatServicing = PreviewChatServicing()
    let agentToolComponent = AgentToolComponent()
    var editorService: (any AbstractEditorServicing)? { nil }

    func makePluginContext(
        activeSectionID: String,
        activeSectionTitle: String,
        chatSection: LumiChatSectionLayout,
        isChatSectionVisible: Bool?,
        additionalDependencies: (inout LumiPluginDependencies) -> Void
    ) -> LumiPluginContext {
        var deps = LumiPluginDependencies()
        additionalDependencies(&deps)
        return LumiPluginContext(
            activeSectionID: activeSectionID,
            activeSectionTitle: activeSectionTitle,
            chatSection: chatSection,
            isChatSectionVisible: isChatSectionVisible ?? chatSection.isVisible,
            dependencies: deps,
            lumiCore: self
        )
    }
}

@MainActor
enum PreviewEditorSwiftSupport {
    static let lumiCore: any LumiCoreAccessing = PreviewLumiCoreStub()
}
