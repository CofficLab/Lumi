import Foundation
import Testing
@testable import LumiKernel

/// `MessageTimelineProviding` 的内核契约测试(占位)。
///
/// 模块对应:`Sources/LumiKernel/Providers/MessageTimelineProviding.swift`。
/// 数据源实现当前在 `MessageTimelinePlugin`(插件层),故内核侧暂只覆盖协议
/// 与 `ObservableMessageTimelineBox` 桥接的可观测性契约。
///
/// TODO(将来补充):
/// - box 把 service.objectWillChange 转发到自身 publisher
/// - service 为高频服务,注册时不转发 kernel 全局广播(注册链路断言)
@Suite("MessageTimelineProviding", .disabled("协议契约待补充"))
@MainActor
struct MessageTimelineProvidingTests {
}
