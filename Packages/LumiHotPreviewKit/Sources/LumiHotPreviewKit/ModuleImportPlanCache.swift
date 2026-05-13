import Foundation
import LumiPreviewKit

public extension LumiHotPreviewPackage {
    actor ModuleImportPlanCache {
        private var plansByStrategy: [LumiPreviewPackage.BuildStrategy: ModuleImportPlan] = [:]

        public init() {}

        public func plan(for buildStrategy: LumiPreviewPackage.BuildStrategy) -> ModuleImportPlan? {
            plansByStrategy[buildStrategy]
        }

        public func store(
            _ plan: ModuleImportPlan,
            for buildStrategy: LumiPreviewPackage.BuildStrategy
        ) {
            plansByStrategy[buildStrategy] = plan
        }

        public func removeAll() {
            plansByStrategy.removeAll()
        }
    }
}
