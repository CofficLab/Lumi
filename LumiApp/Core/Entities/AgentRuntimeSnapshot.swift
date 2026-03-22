import Foundation

/// `AgentRuntime` runtime 投影快照（供 Handler / 协调逻辑只读使用）。
struct AgentRuntimeSnapshot: Sendable {
    let pendingPermissionRequest: PermissionRequest?
    let depthWarning: DepthWarning?
}
