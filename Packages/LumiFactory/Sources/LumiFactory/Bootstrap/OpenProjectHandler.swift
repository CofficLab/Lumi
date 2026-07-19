import Foundation

/// 打开项目处理器（简化版）
///
/// 在完整实现中，负责处理外部打开项目的请求。
@MainActor
public final class OpenProjectHandler {
    public static let shared = OpenProjectHandler()

    private init() {}

    public func configure(lumiCore: Any) {
        // TODO: 配置 LumiCore 引用
    }

    public func requestOpen(path: String) {
        // TODO: 实现项目切换逻辑
    }
}