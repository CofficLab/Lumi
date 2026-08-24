import FactoryCADDesigner2
import KernelCore
import ProviderContentView
import ProviderToolManager
import Testing

@Suite("FactoryCADDesigner2")
@MainActor
struct FactoryCADDesigner2Tests {
    @Test("专用宿主启动 CAD 工作区与完整工具集")
    func startsCADDesigner() throws {
        let kernel = try FactoryCADDesigner2.makeKernel()

        #expect(kernel.isPluginRegistered(id: FactoryCADDesigner2.cadDesignerPluginID))
        #expect(kernel.isPluginEnabled(id: FactoryCADDesigner2.cadDesignerPluginID))
        #expect(kernel.resolveProvider((any ContentViewProviding).self) != nil)
        let names = Set(kernel.resolveProvider((any ToolManagerProviding).self)?.allTools().map(\.name) ?? [])
        #expect([
            "cad_create_project", "cad_load_project", "cad_save_project", "cad_build_frame",
            "cad_place_profile", "cad_place_connector", "cad_update_profile", "cad_generate_bom",
            "cad_connect_components", "cad_optimize_cutting",
        ].allSatisfy(names.contains))
    }

    @Test("主窗口与设置窗口可共享同一 CAD 内核")
    func assemblesSharedViews() throws {
        let kernel = try FactoryCADDesigner2.makeKernel()
        _ = try FactoryCADDesigner2.makeMainView(kernel: kernel)
        _ = try FactoryCADDesigner2.makeSettingsView(kernel: kernel)
    }
}
