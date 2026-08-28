import Foundation
import os

/// V2 runtime state formerly owned by the legacy `LumiPlugin` facade.
public enum GoalTaskPlugin {
    nonisolated(unsafe) public static var _sharedManager: GoalStateManager?
    nonisolated public static func currentManager() -> GoalStateManager? { _sharedManager }
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.goal-task")
}

// Keep the old internal spelling available to the migrated V2 files while no
// longer conforming to or importing the legacy kernel protocol.
typealias Plugin = GoalTaskPlugin
