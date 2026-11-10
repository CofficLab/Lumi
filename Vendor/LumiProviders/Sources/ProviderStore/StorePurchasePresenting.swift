import Foundation

/// 购买面板呈现能力协议。
///
/// 回答一个问题：**请商店把购买面板弹出来**。
///
/// 撞限的免费用户需要一个「点一下就能付费」的入口，但触发点分布在各个
/// 插件里（仓库视图、拖放导入、主窗口）。让它们各自实现购买界面，等于把
/// 商店 UI 的组装逻辑复制到每个触发点，还会让「商店插件没装」这件事在
/// 每个触发点各写一遍降级逻辑。
///
/// 这一层只暴露「请商店呈现购买面板」这一个动作：商店插件是唯一的实现方，
/// 负责决定用什么形态呈现（overlay / sheet）、呈现什么内容；触发方不需要
/// 知道这些。
///
/// ## 为什么放在 Provider 包
///
/// 购买面板的**内容**由商店插件拥有，但「能不能呈现」是**能力**，两者分离
/// 才符合项目的 Provider / 插件边界：契约在 Provider 包，实现（Provider
/// 生产者）在插件包。
///
/// ## 线程语义
/// 主线程语义（`@MainActor`）：呈现动作必然要驱动 UI。
@MainActor
public protocol StorePurchasePresenting: AnyObject, Sendable {
    /// 呈现购买面板。
    ///
    /// 重复调用不会叠加多个面板：已有面板时只把它带到前台。
    func presentPurchase()
}

/// 空实现呈现器：用于「没有商店功能」的场景。
///
/// 消费方（撞限引导等）可以用它占位，让降级逻辑收敛在一处：
/// 商店插件缺席时传入本类型，调用 `presentPurchase()` 不做任何事。
@MainActor
public final class NoopStorePurchasePresenting: StorePurchasePresenting {
    public init() {}
    public func presentPurchase() {}
}
