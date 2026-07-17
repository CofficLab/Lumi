import Foundation
import LumiCoreKit

final class PreviewLumiCoreStub: LumiCoreAccessing {
    var dataRootDirectory: URL { URL(fileURLWithPath: "/tmp/preview") }
    var logoRegistry: LogoRegistry { .shared }
    let projectComponent = ProjectComponent()
    let layoutComponent = LayoutComponent(state: LayoutState())
    let chatService: any LumiChatServicing = PreviewChatServicing()
    var editorService: (any AbstractEditorServicing)? { nil }
    var coreDataDirectory: URL { URL(fileURLWithPath: "/tmp/preview/Core") }
    func pluginDataDirectory(for pluginName: String) -> URL {
        URL(fileURLWithPath: "/tmp/preview/\(pluginName)")
    }
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
enum PreviewEditorSwiftSupport {
    static let lumiCore: any LumiCoreAccessing = PreviewLumiCoreStub()
}
