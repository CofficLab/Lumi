import Foundation
import LumiCoreKit

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
        showsRail: Bool,
        showsPanelChrome: Bool,
        isChatSectionVisible: Bool?,
        additionalDependencies: (inout LumiPluginDependencies) -> Void
    ) -> LumiPluginContext {
        var deps = LumiPluginDependencies()
        additionalDependencies(&deps)
        return LumiPluginContext(
            activeSectionID: activeSectionID,
            activeSectionTitle: activeSectionTitle,
            chatSection: chatSection,
            showsRail: showsRail,
            showsPanelChrome: showsPanelChrome,
            isChatSectionVisible: isChatSectionVisible ?? chatSection.isVisible,
            dependencies: deps,
            lumiCore: self
        )
    }
}

@MainActor
enum PreviewEditorFileTreeSupport {
    static let lumiCore: any LumiCoreAccessing = PreviewLumiCoreStub()
}
