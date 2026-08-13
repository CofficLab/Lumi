import SwiftUI

private struct LumiTurnActivitySummariesKey: EnvironmentKey {
    static let defaultValue: [UUID: LumiTurnActivitySummary] = [:]
}

public extension EnvironmentValues {
    var lumiTurnActivitySummaries: [UUID: LumiTurnActivitySummary] {
        get { self[LumiTurnActivitySummariesKey.self] }
        set { self[LumiTurnActivitySummariesKey.self] = newValue }
    }
}
