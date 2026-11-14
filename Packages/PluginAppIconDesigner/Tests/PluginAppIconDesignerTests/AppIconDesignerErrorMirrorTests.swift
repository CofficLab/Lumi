import Foundation
import Testing
@testable import PluginAppIconDesigner

/// 回归 #293：`objectWillChange` 在新值安装前触发，ViewModel 若在该回调里同步读 store
/// 会镜像旧值，导出错误永远不显示、成功后旧错误也不清除。镜像必须读到安装后的新值。
@Suite("AppIconDesigner 错误镜像", .serialized)
@MainActor
struct AppIconDesignerErrorMirrorTests {
    /// store 变更经 main actor Task 镜像；让出当前 tick 直到镜像落地再断言。
    private func settle(_ condition: () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            await Task.yield()
        }
    }

    @Test("导出错误及时镜像，成功后旧错误清除")
    func exportErrorIsMirroredAndClearedOnSuccess() async {
        let store = IconDocumentStore()
        let vm = AppIconDesignerViewModel(store: store)
        #expect(vm.lastError == nil)

        store.setError("export failed: target not writable")
        await settle { vm.lastError == "export failed: target not writable" }
        #expect(vm.lastError == "export failed: target not writable")

        let url = URL(fileURLWithPath: "/tmp/icon-export.png")
        store.setExportURL(url)
        await settle { vm.lastError == nil && vm.lastExportURL == url }
        #expect(vm.lastError == nil)
        #expect(vm.lastExportURL == url)
    }
}