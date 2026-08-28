import FactoryDatabaseManager
import Foundation
import Testing

@MainActor
struct FactoryDatabaseManagerTests {
    @Test("dedicated assembly enables the editor and database plugins")
    func assemblesDedicatedKernel() throws {
        let kernel = try FactoryDatabaseManager.makeKernel()
        #expect(kernel.isPluginEnabled(id: "com.coffic.lumi.plugin.editor-host"))
        #expect(kernel.isPluginEnabled(id: "com.coffic.lumi.plugin.database-manager"))
        #expect(FactoryDatabaseManager.openExternalFile(URL(fileURLWithPath: "/tmp/factory.sqlite"), kernel: kernel))
    }
}
