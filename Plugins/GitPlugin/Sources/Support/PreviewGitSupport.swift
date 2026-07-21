import Foundation
import LumiKernel

/// Preview-time stub for `LumiCoreAccessing` and `AppGitVM`.
///
/// `LumiCoreAccessing` is a protocol that the real `LumiCore` conforms to.
/// For SwiftUI Previews we don't want to spin up the entire boot sequence,
/// so we provide a minimal stub that satisfies the protocol surface used by
/// Git plugin views (only `projectState` is touched at preview time).
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
enum PreviewGitSupport {
    static let lumiCore: any LumiCoreAccessing = PreviewLumiCoreStub()
    static let gitVM = AppGitVM()
}
