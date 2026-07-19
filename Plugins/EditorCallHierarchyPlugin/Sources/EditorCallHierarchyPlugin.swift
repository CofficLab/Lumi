import EditorService
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class EditorCallHierarchyPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.editor-bottom-call-hierarchy"
    public let name = "Editor Call Hierarchy"
    public let order = 6

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Panel items are registered via panelBottomTabItems/panelRailTabItems
    }

    public func boot(kernel: LumiKernel) async throws {}
}
