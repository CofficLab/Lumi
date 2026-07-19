import EditorService
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class EditorProblemsPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.editor-bottom-problems"
    public let name = "Editor Problems"
    public let order = 1

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Panel items are registered via panelBottomTabItems/panelRailTabItems
    }

    public func boot(kernel: LumiKernel) async throws {}
}
