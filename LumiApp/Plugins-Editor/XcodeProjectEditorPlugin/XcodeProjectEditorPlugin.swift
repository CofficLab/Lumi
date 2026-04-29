import Foundation
import SwiftUI

@objc(LumiXcodeProjectEditorPlugin)
@MainActor
final class XcodeProjectEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.xcode-project-editor"
    let displayName: String = String(localized: "Xcode Project Editor", table: "XcodeProjectEditor")
    override var description: String {
        String(localized: "Provides Xcode project identity, build context, and sourcekit-lsp integration for Swift projects.", table: "XcodeProjectEditor")
    }
    let order: Int = 4  // 在 LSP Service 之前加载，确保 build context 就绪
    
    /// Build Context Provider 实例
    let buildContextProvider = XcodeBuildContextProvider()
    
    func register(into registry: EditorExtensionRegistry) {
        // 向 Bridge 注册 buildContextProvider，让 LSPService 能读取 build context
        XcodeProjectContextBridge.shared.registerBuildContextProvider(buildContextProvider)
    }
}
