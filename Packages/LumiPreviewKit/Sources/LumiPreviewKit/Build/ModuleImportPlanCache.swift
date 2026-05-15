import Foundation

public extension LumiPreviewFacade {
    actor ModuleImportPlanCache {
        private var plansByStrategy: [LumiPreviewFacade.BuildStrategy: ModuleImportPlan] = [:]

        public init() {}

        public func plan(for buildStrategy: LumiPreviewFacade.BuildStrategy) -> ModuleImportPlan? {
            plansByStrategy[buildStrategy]
        }

        public func store(
            _ plan: ModuleImportPlan,
            for buildStrategy: LumiPreviewFacade.BuildStrategy
        ) {
            plansByStrategy[buildStrategy] = plan
        }

        public func removeAll() {
            plansByStrategy.removeAll()
        }
    }
}
