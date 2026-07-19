import EditorService
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class EditorSymbolsPanelPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.editor-bottom-symbols"
    public let name = "Editor Symbols"
    public let order = 3

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Panel items are registered in panelBottomTabItems/panelRailTabItems methods
    }

    public func boot(kernel: LumiKernel) async throws {}
}
