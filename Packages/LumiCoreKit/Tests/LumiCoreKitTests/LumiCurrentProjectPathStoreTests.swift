import Foundation
import Testing
import LumiCoreKit

@MainActor
struct LumiCurrentProjectPathStoreTests {
    @Test func publishesPathChangeNotificationAndUpdatesWindowProjectVMImmediately() async {
        let store = LumiCurrentProjectPathStore()
        let vm = WindowProjectVM(store: store)

        #expect(vm.currentProjectPath.isEmpty)

        store.setCurrentProjectPath("/tmp/GitOK", reason: "测试用例")
        await Task.yield()

        #expect(vm.currentProjectPath == "/tmp/GitOK")
    }
}
