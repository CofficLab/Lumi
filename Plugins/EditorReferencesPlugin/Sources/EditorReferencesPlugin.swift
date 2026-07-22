import EditorService
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class EditorReferencesPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.editor-bottom-references"
    public let name = "Editor References"
    public let order = 3
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        // Panel items are registered via panelBottomTabItems/panelRailTabItems
    }

    public func boot(kernel: LumiKernel) async throws {}
}
