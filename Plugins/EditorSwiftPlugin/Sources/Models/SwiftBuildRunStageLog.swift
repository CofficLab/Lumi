import Foundation

public enum SwiftBuildRunLogStage: String, CaseIterable, Identifiable, Sendable {
    case preflight
    case build
    case launch

    public var id: String { rawValue }
}

public enum SwiftBuildRunStageStatus: Equatable, Sendable {
    case pending
    case active
    case completed
    case failed
    case skipped
}

public struct SwiftBuildRunStageRecord: Identifiable, Equatable {
    public let stage: SwiftBuildRunLogStage
    public var status: SwiftBuildRunStageStatus
    public var outputText: String
    public var omittedLineCount: Int

    public var id: SwiftBuildRunLogStage { stage }
}

struct SwiftBuildRunStageOutputState {
    var lineBuffer: [String] = []
    var pendingLines: [String] = []
    var outputText: String = ""
    var omittedLineCount: Int = 0
}
