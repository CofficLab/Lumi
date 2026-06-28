import Foundation
import os

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

/// 基于 `os.Logger` 的 `RAGLogger` 适配器
///
/// RAGKit 仅依赖 `RAGLogger` 协议，对 `os.Logger` 无感知。
/// 由 Plugin 层提供此具体实现：所有输出统一走 `RAGPlugin.logger`，
/// 并按 [日志规范](../../../../../../.agent/rules/swift-log.md) 自带 `RAGPlugin.t` 前缀。
/// 这样 RAGKit 内部各调用点无需各自加前缀。
///
/// 同时在这里集中做 verbose 控制：`info` 级别的常规流程/性能日志
/// 受 `RAGPlugin.verbose` 控制（默认关闭），`warning`/`error` 始终输出。
struct OSLogRAGLogger: RAGLogger {
    func info(_ message: String) {
        guard RAGPlugin.verbose else { return }
        RAGPlugin.logger.info("\(RAGPlugin.t)\(message)")
    }
    func warning(_ message: String) {
        RAGPlugin.logger.warning("\(RAGPlugin.t)\(message)")
    }
    func error(_ message: String) {
        RAGPlugin.logger.error("\(RAGPlugin.t)\(message)")
    }
}
