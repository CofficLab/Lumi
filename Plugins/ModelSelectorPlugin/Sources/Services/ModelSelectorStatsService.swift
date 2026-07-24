import Foundation
import LumiKernel

/// Stats aggregation now lives in LumiKernel.ModelUsageStatsService.
/// Keep old names as type aliases so call sites don't need changing.
typealias ModelSelectorStatsService = ModelUsageStatsService
typealias ModelSelectorStatsSnapshot = ModelUsageStatsSnapshot
