import Foundation
import LumiCoreMessage

/// 消息渲染器注册服务
///
/// 负责管理所有已注册的消息渲染器，提供渲染器查询接口。
/// 插件通过 LumiPlugin.messageRenderers(kernel:) 贡献渲染器，
/// 由本服务统一注册和管理。
@MainActor
public protocol MessageRendererManaging: AnyObject {
    /// 所有已注册的消息渲染器，按 order 降序排列
    func allMessageRenderers() -> [LumiMessageRendererItem]

    /// 注册消息渲染器
    func registerMessageRenderer(_ renderer: LumiMessageRendererItem)

    /// 注销消息渲染器
    func unregisterMessageRenderer(id: String)

    /// 查找可渲染指定消息的渲染器
    func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem?
}
