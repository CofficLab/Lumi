import FactoryAppIconDesigner2
import KernelCore
import ProviderActivityBar
import ProviderRailView
import ProviderToolManager
import Testing

@Suite("FactoryAppIconDesigner2")
@MainActor
struct FactoryAppIconDesigner2Tests {
    @Test("专用宿主启动图标设计器及其完整工具集")
    func startsDesignerAsAlwaysOn() throws {
        let kernel = try FactoryAppIconDesigner2.makeKernel()

        #expect(kernel.isPluginRegistered(id: FactoryAppIconDesigner2.appIconDesignerPluginID))
        #expect(kernel.isPluginEnabled(id: FactoryAppIconDesigner2.appIconDesignerPluginID))
        #expect(kernel.resolveProvider((any ActivityBarProviding).self)?.items.contains {
            $0.ownerPluginID == FactoryAppIconDesigner2.appIconDesignerPluginID
        } == true)
        #expect(kernel.resolveProvider((any RailViewProviding).self)?.tabs.contains {
            $0.groupID == FactoryAppIconDesigner2.appIconDesignerPluginID
        } == true)
        let toolNames = Set(kernel.resolveProvider((any ToolManagerProviding).self)?.allTools().map(\.name) ?? [])
        #expect([
            "list_icon_documents", "create_icon_document", "apply_icon_preset",
            "load_icon_document", "save_icon_document", "set_icon_background",
            "add_icon_shape", "update_icon_shape", "update_icon_layer",
            "lint_icon_document", "preview_icon", "export_icon_svg",
            "export_app_icon", "register_app_icon_artifact", "review_icon",
        ].allSatisfy(toolNames.contains))
    }

    @Test("主窗口与设置窗口可复用同一内核装配")
    func assemblesSharedViews() throws {
        let kernel = try FactoryAppIconDesigner2.makeKernel()
        _ = try FactoryAppIconDesigner2.makeMainView(kernel: kernel)
        _ = try FactoryAppIconDesigner2.makeSettingsView(kernel: kernel)
    }
}
