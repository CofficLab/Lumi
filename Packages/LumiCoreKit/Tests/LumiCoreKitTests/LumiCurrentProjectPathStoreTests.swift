import Foundation
import Testing
import LumiCoreKit

@MainActor
struct LumiCurrentProjectPathStoreTests {
    @Test func publishesPathChangeNotificationAndUpdatesWindowProjectVMImmediately() async {
        let store = LumiCurrentProjectPathStore()
        let vm = WindowProjectVM(store: store)

        #expect(vm.currentProjectPath.isEmpty)

        store.setCurrentProjectPath("/tmp/GitOK")
        await Task.yield()

        #expect(vm.currentProjectPath == "/tmp/GitOK")
    }
}
