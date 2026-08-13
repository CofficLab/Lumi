import Foundation

@MainActor
public protocol ToolServiceEnvironment: AnyObject {
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity
    var currentProjectPath: String? { get }
}
