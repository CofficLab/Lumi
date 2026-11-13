import Foundation

/// 导出内容的取舍策略。
enum ConversationExportMode: Equatable, Sendable {
    /// 开发调试：保留推理、工具调用、ID、路径等全部技术细节。
    case debug
    /// 分享对话：只保留用户与助手的可见内容，隐藏技术细节。
    case share
}
