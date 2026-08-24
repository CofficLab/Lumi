import FactoryDatabaseManager2
import Foundation
import Testing

@MainActor
struct FactoryDatabaseManager2Tests {
    @Test("dedicated assembly enables the editor and database plugins")
    func assemblesDedicatedKernel() throws {
        let kernel = try FactoryDatabaseManager2.makeKernel()
        #expect(kernel.isPluginEnabled(id: "com.coffic.lumi.plugin.editor-host"))
        #expect(kernel.isPluginEnabled(id: "com.coffic.lumi.plugin.database-manager"))
        #expect(FactoryDatabaseManager2.openExternalFile(URL(fileURLWithPath: "/tmp/factory.sqlite"), kernel: kernel))
    }
}
