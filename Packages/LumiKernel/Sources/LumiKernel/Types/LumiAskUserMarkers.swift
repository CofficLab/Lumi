import Foundation

/// `ask_user` 工具与 Agent 循环之间的约定标记。
public enum LumiAskUserMarkers {
    public static let pendingPrefix = "__ASK_USER_PENDING__"
    public static let errorPrefix = "__ASK_USER_ERROR__"

    public static func isPendingResponse(_ content: String) -> Bool {
        content.hasPrefix("\(pendingPrefix)\n") || content == pendingPrefix
    }
}
