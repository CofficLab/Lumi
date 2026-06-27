import Foundation
import WorkspaceFileKit

/// 进程级「已读取文件」状态注册表。
///
/// `read_file` 与 `edit_file` 是彼此独立的工具实例，但共享同一份按会话隔离的读取状态，
/// 以实现「先读后写 + 乐观并发控制」：编辑前若发现文件在读取后被外部修改则拒绝覆盖。
/// 通过共享单例避免改动工具协议签名（工具是无状态 struct，无法直接持有跨调用状态）。
enum ReadFileStateRegistry {
    /// 全局共享状态。按 conversationID 隔离，会话结束时由上层调用 clear 清理。
    static let shared = WorkspaceReadFileState()
}
