import Foundation
import LumiKernel

/// Minimal `ObservableObject` stub used for SwiftUI `#Preview` blocks.
///
/// The protocol surface of `LumiCoreAccessing` only requires `chatService`
/// to be any `ObservableObject`, so we provide a tiny placeholder here.
@MainActor
private final class PreviewChatServiceStub: ObservableObject {}

@MainActor
final class PreviewLumiCoreStub: LumiCoreAccessing {
    let storage = StorageComponent(dataRootDirectory: URL(fileURLWithPath: "/tmp/preview"))
    let logoComponent = LogoComponent()
    let projectComponent = ProjectComponent()
    let layoutComponent = LayoutComponent(state: LayoutState())
    let chatService: any ObservableObject = PreviewChatServiceStub()
    let agentToolComponent = AgentToolComponent()
    var editorService: (any AbstractEditorServicing)? { nil }

    func registerService<T>(_ type: T.Type, _ instance: T) {}
    func resolveService<T>(_ type: T.Type) -> T? { nil }

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
enum PreviewEditorFileTreeSupport {
    static let lumiCore: any LumiCoreAccessing = PreviewLumiCoreStub()
}