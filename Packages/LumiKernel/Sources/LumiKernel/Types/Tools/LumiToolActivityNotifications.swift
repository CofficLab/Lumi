import Foundation

public extension Notification.Name {
    /// Posted after a tool-call record has been accepted by ToolManager storage.
    static let lumiToolActivityDidChange = Notification.Name("Lumi.ToolActivityDidChange")
}
