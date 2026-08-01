import Foundation
import SwiftUI

/// 标记"当前正在进行的 turn"内、那些**默认应展开**显示的工具步骤组
/// (即带工具调用的助手消息 id)。
///
/// 仅用于 **V1 (brief)** 模式下的「可折叠步骤组」:由消息列表视图模型
/// 根据 turn 是否进行中计算后,经 SwiftUI Environment 注入渲染层;
/// 渲染层据此决定每个步骤组默认展开还是收起。
///
/// - turn 进行中:本轮(上一条最终回复之后)的工具步骤组 id 都在此集合中 → 默认展开。
/// - turn 未进行中:集合为空 → 所有步骤组默认收起成一行摘要。
///
/// 用户的手动展开/收起由组件自身的 `@State` 覆盖,不依赖此环境值。
private struct LumiActiveToolGroupIDsKey: EnvironmentKey {
    static let defaultValue: Set<UUID> = []
}

extension EnvironmentValues {
    /// 当前应默认展开显示的工具步骤组(助手消息 id)集合。
    public var lumiActiveToolGroupIDs: Set<UUID> {
        get { self[LumiActiveToolGroupIDsKey.self] }
        set { self[LumiActiveToolGroupIDsKey.self] = newValue }
    }
}
