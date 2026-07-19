import Foundation

// MARK: - Send Context

/// 发送上下文
///
/// 包含消息发送时的上下文信息。
public struct SendContext: Sendable {
    /// 消息内容
    public var content: String

    /// 当前项目路径
    public var projectPath: String?

    /// 额外元数据
    public var metadata: [String: String]

    public init(content: String, projectPath: String? = nil, metadata: [String: String] = [:]) {
        self.content = content
        self.projectPath = projectPath
        self.metadata = metadata
    }
}

// MARK: - Send Middleware

/// 发送中间件协议
///
/// 在消息发送前对内容进行预处理。
/// 中间件可以修改消息内容、添加元数据或阻止发送。
public protocol SendMiddleware: Sendable {
    /// 处理发送上下文
    ///
    /// - Parameter context: 原始发送上下文
    /// - Returns: 处理后的发送上下文，返回 nil 表示阻止发送
    func prepare(_ context: SendContext) async throws -> SendContext?
}