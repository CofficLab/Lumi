import SwiftUI

// MARK: - Panel Bottom Item

/// 底部面板（PanelBottom / content footer）入口项（由插件注入）。
///
/// 仅描述底部面板上的一条 tab（id / 标题 / 图标 / 排序 / 归属插件），
/// 并携带该 tab 激活时渲染的内容视图。内容视图工厂只会在对应 tab
/// 处于激活状态时被宿主调用，因此可用于延迟创建（如终端会话）。
///
/// `ownerPluginID` 用于跟踪该入口所属的插件：插件卸载/禁用时按此批量撤回，
/// 重新启用时重新注册。
@MainActor
public struct PanelBottomItem: Identifiable {
    /// 全局唯一 id，约定为 `<ownerPluginID>.<suffix>`。
    public let id: String
    /// tab 标题（调用方负责传入已本地化的文案）。
    public let title: String
    /// 可选 SF Symbol 图标名。
    public let systemImage: String?
    /// 排序权重（升序；同权重按 id 升序）。
    public let order: Int
    /// 该入口所属插件的 id。
    public let ownerPluginID: String
    /// 入口内容视图工厂（仅在该 tab 激活时被调用）。
    private let viewProvider: @MainActor () -> AnyView

    public init(
        id: String,
        title: String,
        systemImage: String? = nil,
        order: Int = 0,
        ownerPluginID: String,
        viewProvider: @escaping @MainActor () -> AnyView
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = order
        self.ownerPluginID = ownerPluginID
        self.viewProvider = viewProvider
    }

    /// 生成入口内容视图。
    public func makeView() -> AnyView {
        viewProvider()
    }
}
