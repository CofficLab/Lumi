import FactoryAppIconDesigner
import KernelCore
import ProviderDocsView
import Testing

/// 专用宿主的 AlwaysOn 包装必须完整转发注册生命周期。
///
/// `AppIconDesignerPlugin` 在 `onRegister` / `onUnregister` 注入与撤回 About 与 Manual
/// 文档；包装只应改变启用策略。若漏转这两个钩子，独立 App 的设置页永远没有
/// 关于页与说明书，而完整 Lumi 宿主不走包装所以正常（#321）。
@Suite("FactoryAppIconDesigner registration lifecycle")
@MainActor
struct AlwaysOnRegistrationTests {

    @Test("启动后图标设计器的关于页与说明书已注册")
    func bootRegistersAboutAndManual() throws {
        let kernel = try FactoryAppIconDesigner.makeKernel()
        let docs = kernel.resolveProvider((any DocsViewProviding).self)
        let id = FactoryAppIconDesigner.appIconDesignerPluginID

        #expect(docs?.aboutEntries.contains { $0.id == id } == true)
        #expect(docs?.manualEntries.contains { $0.id == id } == true)
    }
}