import Foundation

/// RAGKit 日志协议
///
/// 用于解耦对 MagicKit.AppLogger 的直接依赖。
/// Plugin 层提供适配器实现，RAGKit 内部通过此协议输出日志。
public protocol RAGLogger: Sendable {
    func info(_ message: String)
    func error(_ message: String)
    func warning(_ message: String)
}

/// 默认空日志实现（不输出任何内容）
///
/// 用于测试场景或不需要日志的场景。
public struct NullRAGLogger: RAGLogger, Sendable {
    public init() {}
    public func info(_: String) {}
    public func error(_: String) {}
    public func warning(_: String) {}
}
