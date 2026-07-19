import EditorService
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class EditorOutlinePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.editor-rail-outline"
    public let name = "Editor Outline"
    public let order = 1

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Panel items are registered via panelBottomTabItems/panelRailTabItems
    }

    public func boot(kernel: LumiKernel) async throws {}
}
