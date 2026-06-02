import Foundation
import LumiPreviewKit
import Testing

@Suite("ModuleImportPlanCache")
struct ModuleImportPlanCacheTests {
    private let spmStrategy = LumiPreviewFacade.BuildStrategy.spm(
        packageDirectory: URL(fileURLWithPath: "/tmp/PreviewPkg"),
        targetName: "App"
    )
    private let xcodeStrategy = LumiPreviewFacade.BuildStrategy.xcode(
        projectURL: URL(fileURLWithPath: "/tmp/Demo.xcodeproj"),
        scheme: "Demo",
        configuration: "Debug"
    )

    @Test("3.1 stores and returns plan for build strategy")
    func storesAndReturnsPlan() async {
        let cache = LumiPreviewFacade.ModuleImportPlanCache()
        let plan = samplePlan(moduleName: "App")

        await cache.store(plan, for: spmStrategy)
        let loaded = await cache.plan(for: spmStrategy)

        #expect(loaded == plan)
    }

    @Test("3.2 keeps plans isolated per build strategy")
    func isolatesPlansPerStrategy() async {
        let cache = LumiPreviewFacade.ModuleImportPlanCache()
        let spmPlan = samplePlan(moduleName: "App")
        let xcodePlan = samplePlan(moduleName: "Demo")

        await cache.store(spmPlan, for: spmStrategy)
        await cache.store(xcodePlan, for: xcodeStrategy)

        #expect(await cache.plan(for: spmStrategy) == spmPlan)
        #expect(await cache.plan(for: xcodeStrategy) == xcodePlan)
    }

    @Test("3.3 removeAll clears stored plans")
    func removeAllClearsPlans() async {
        let cache = LumiPreviewFacade.ModuleImportPlanCache()
        await cache.store(samplePlan(moduleName: "App"), for: spmStrategy)

        await cache.removeAll()

        #expect(await cache.plan(for: spmStrategy) == nil)
    }

    private func samplePlan(moduleName: String) -> LumiPreviewFacade.ModuleImportPlan {
        LumiPreviewFacade.ModuleImportPlan(
            moduleName: moduleName,
            searchPaths: ["/tmp/Modules"],
            compilerArguments: ["-I/tmp/Modules"],
            moduleArtifactPath: "/tmp/\(moduleName).swiftmodule"
        )
    }
}
