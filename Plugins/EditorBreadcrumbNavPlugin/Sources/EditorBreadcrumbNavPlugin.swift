import EditorService
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class EditorBreadcrumbNavPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.editor-breadcrumb-header"
    public let name = "Editor Breadcrumb Header"
    public let order = 80

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // Panel items are registered via panelBottomTabItems/panelRailTabItems
    }

    public func boot(kernel: LumiKernel) async throws {}
}
