import Foundation
import Testing
@testable import PluginMessageListBrief

/// 消息列表视图（V1 / 简洁模式）的**状态生命周期**回归测试。
///
/// ## 复现的缺陷
///
/// `ListV1View` 把三个**有状态**的引用类型对象用 `let` 声明为普通存储属性：
///
/// ```swift
/// private let atBottomBox = AtBottomBox()
/// private let scrollCoordinator = MessageListScrollCoordinator()
/// private let bottomScrollController = ScrollViewBottomController()
/// ```
///
/// SwiftUI 的 struct 存储属性初始化表达式**在每次 `init` 调用时都会执行**。
/// 而 `ListV1View` 是由宿主在 body 里生产的：
///
/// ```swift
/// // ProviderChatSection/.../DefaultChatSectionProviding.swift
/// item.makeView()   // → AnyView(ListV1View(...))  → 走 ListV1View.init
/// ```
///
/// 因此**宿主每重绘一次，这三个对象就全部被换新**，它们攒的状态随之清零：
/// - `ScrollViewBottomController` 丢失 `NSScrollView` 绑定 → `isAttached == false`
///   → `prepareInitialBottom` 走「只滚一次、不做几何收敛」的分支；
/// - `MessageListScrollCoordinator` 丢失 `preparationSequence` / `scrollGeneration`
///   → `deinit` 还会静默 cancel 掉正在进行的滚动任务；
/// - `AtBottomBox` 丢失「用户是否在底部」→ 初值 `true` 被写回
///   → 用户已经上滚，流式跟随滚动却仍被开启。
///
/// 会话切换必然触发宿主重绘（`selectedConversationID.didSet` →
/// `notifyConversationObservers(.selected)` → `chat.refreshItems()` →
/// `objectWillChange.send()`），所以这个状态丢失**每次切换都会发生**。
///
/// 对 V1 而言后果比 V2 更重：新旧两个 `MessageListScrollCoordinator` 实例
/// 会**同时驱动同一个 scroll view**（新实例的 `preparationSequence` 与旧实例
/// 互不相识，`cancelPendingTasks()` 也 cancel 不掉对方），几何收敛因此永远
/// 不稳定，`prepareInitialBottom` 不会返回 `true` —— 首屏遮罩就此永久挂起。
///
/// ## 为什么用 Mirror 而不是加生产代码的观察缝
///
/// Mirror 可以在**不改动任何生产代码**的前提下读到 struct 的存储属性，
/// 于是「复现」与「修复」被彻底分开。
///
/// ## 状态承载方式改变后，断言落在哪里
///
/// 修复把三个对象移进了 `MessageListRuntime` 容器，由视图以 `@StateObject`
/// 持有。于是「状态不丢」这个保证由两件事共同承担：
///
/// 1. **视图必须用 identity 缓存机制承载容器** —— 否则容器本身也会被重建；
/// 2. **容器成员的实例必须稳定** —— 否则成员之间会各持一份。
@MainActor
private func makeListV1View() -> ListV1View {
    let services = MessageListServices(
        conversations: nil,
        developerMode: nil,
        messages: nil,
        rendering: nil,
        agentTurn: nil
    )
    return ListV1View(
        services: services,
        messageListVM: ConversationMessageListVM(services: services),
        stateVM: ConversationStateVM()
    )
}

/// 取出视图的存储属性中，**直接**持有的类实例（`let` 声明的那类）。
///
/// - Note: property wrapper 的 backing storage 在 Mirror 里的 label 以 `_`
///   开头（SwiftUI 生成的 `_stateObject` / `_observedObject` …）。它们不是
///   「每次 init 重建一次」的普通存储属性，故不在此列。
private func plainClassStorages(of view: Any) -> [String] {
    Mirror(reflecting: view).children.compactMap { child in
        guard let label = child.label, !label.hasPrefix("_") else { return nil }
        guard Mirror(reflecting: child.value).displayStyle == .class else { return nil }
        return label
    }
}

/// 取出视图用 `StateObject` 承载的存储属性类型名。
private func stateObjectStorages(of view: Any) -> [String] {
    Mirror(reflecting: view).children.compactMap { child in
        guard let label = child.label, label.hasPrefix("_") else { return nil }
        let typeName = String(describing: type(of: child.value))
        guard typeName.contains("StateObject<") else { return nil }
        return typeName
    }
}

// MARK: - 不变式 1：不得用普通存储属性持有引用类型状态

/// `ListV1View` 不得用**普通存储属性**（非 property wrapper 承载）持有引用类型。
///
/// - Important: 这是根因不变式。只要有任何一个引用类型对象用普通存储属性
///   持有，宿主每次重绘就会重建它，状态必然丢失。
///   `@StateObject` / `@State` 的 backing storage（label 以 `_` 开头）不受影响，
///   因为 SwiftUI 按视图 identity 缓存它们。
@MainActor
@Test("简洁模式消息列表视图：不得用普通存储属性持有引用类型状态")
func listViewMustNotHoldReferenceStateInPlainStoredProperty() {
    let offenders = plainClassStorages(of: makeListV1View())

    #expect(
        offenders.isEmpty,
        """
        这些存储属性是引用类型且不由 property wrapper 承载：\(offenders).
        宿主每次重绘都会重新 init 视图并把它们全部重建，\
        新旧两个滚动协调器会同时驱动同一个 scroll view，\
        几何收敛永远不稳定，首屏遮罩就此永久挂起。
        """
    )
}

// MARK: - 不变式 2：运行时容器必须由 identity 缓存机制承载

/// `ListV1View` 必须用 `@StateObject` 承载运行时状态容器。
///
/// - Important: 上一条只保证「不用裸存储属性」，但换成 `@State` 同样不行 ——
///   `@State` 存的是**值语义**的副本，装不下引用类型对象并保持同一性。
///   只有 `@StateObject` 会按视图 identity 缓存实例，容器里的成员才能
///   跨宿主重绘存活。
///
/// - Note: 这里按**类型名字符串**断言，而不是引用容器类型本身 ——
///   这样「复现」不依赖修复是否已经存在，测试在修复前后都能编译。
@MainActor
@Test("简洁模式消息列表视图：运行时状态容器必须由 StateObject 承载")
func listViewMustCarryRuntimeInStateObject() {
    let stateObjects = stateObjectStorages(of: makeListV1View())

    #expect(
        stateObjects.contains { $0.contains("MessageListRuntime") },
        """
        视图上找不到由 StateObject 承载的 MessageListRuntime，实际有：\(stateObjects).
        运行时容器若不由 StateObject 承载，它会随宿主每次重绘被重建，
        容器成员攒下的状态（滚动序号 / 底部标记 / 滚动视图绑定）依旧会丢失。
        """
    )
}

// MARK: - 不变式 3：首屏就绪必须由带超时兜底的编排器承载

/// `ListV1View` 的首屏就绪判定必须由**带超时兜底的编排器**承载，
/// 不能是一个裸 `@State` 布尔。
///
/// ## 缺陷背景
///
/// V1 曾用 `@State private var isInitialPositionReady` 表达「首屏已定位」。
/// 这个布尔**只有一条置真路径**：收敛过程返回 `true`。
///
/// `MessageListScrollCoordinator.prepareInitialBottom` 的收敛是有界的
/// （`bottomSettleMaxAttempts` 限制轮次），但它**可能返回 false** ——
/// 条件失效（会话被换掉 / 进入加载）、行高迟迟不稳定、滚动视图绑定丢失……
/// 一旦返回 false，`isInitialPositionReady` 就永远是 false，而遮罩的显示
/// 条件是 `messageListVM.isLoading || !isInitialPositionReady` ——
///
/// **没有任何兜底路径，遮罩就此永久挂起。**
///
/// V2 早已用 `InitialPositionGate` 解决：收敛成功、收敛失败、收敛挂死
/// （超预算）三条路径都会放行遮罩。
///
/// - Note: 这里按**类型名字符串**断言，测试在修复前后都能编译。
@MainActor
@Test("简洁模式消息列表视图：首屏就绪必须由带超时兜底的编排器承载")
func listViewMustCarryInitialPositionGate() {
    let stateObjects = stateObjectStorages(of: makeListV1View())

    #expect(
        stateObjects.contains { $0.contains("InitialPositionGate") },
        """
        视图上找不到由 StateObject 承载的 InitialPositionGate，实际有：\(stateObjects).
        裸 @State 布尔只有「收敛返回 true」这一条置真路径：收敛失败或挂死时，
        遮罩将永久挂起，没有任何兜底能救。
        """
    )
}

// MARK: - 不变式 3：容器成员实例必须稳定

/// `MessageListRuntime` 的三个成员在多次访问之间必须是**同一实例**。
///
/// 容器是「同一性」的载体：若成员每次访问都新建，等于把原来的缺陷搬了个家。
@MainActor
@Test("简洁模式运行时容器：成员在多次访问之间必须保持同一实例")
func runtimeMembersKeepStableIdentity() {
    let runtime = MessageListRuntime()

    #expect(runtime.atBottomBox === runtime.atBottomBox)
    #expect(runtime.scrollCoordinator === runtime.scrollCoordinator)
    #expect(runtime.bottomScrollController === runtime.bottomScrollController)
}

/// 容器必须真的持有这三个成员——缺一个就意味着对应状态无处安放。
@MainActor
@Test("简洁模式运行时容器：必须持有底部标记、滚动协调器与底部几何控制器")
func runtimeCarriesAllThreeMembers() {
    let runtime = MessageListRuntime()
    let labels = Set(Mirror(reflecting: runtime).children.compactMap(\.label))

    #expect(labels.contains("atBottomBox"))
    #expect(labels.contains("scrollCoordinator"))
    #expect(labels.contains("bottomScrollController"))
    #expect(runtime.atBottomBox.value == true, "新容器的底部标记应为初值 true")
}

// MARK: - 不变式 4：容器不得发布任何 @Published

/// 容器**不得**声明任何 `@Published`。
///
/// - Important: 容器实现 `ObservableObject` 只是为了满足 `@StateObject` 的要求。
///   一旦它发布属性，成员（尤其 `AtBottomBox`）的写入就会进入 SwiftUI 的
///   invalidation 图，重新打开底部锚点 Preference 反馈环
///   （`@State` → body 重建 → 偏好重报 → 活锁）。
///   详见 `AtBottomBox` 的类型注释。
@MainActor
@Test("简洁模式运行时容器：不得发布任何 @Published（避免重新打开 invalidation 反馈环）")
func runtimePublishesNothing() {
    let published = Mirror(reflecting: MessageListRuntime()).children.filter { child in
        let typeName = String(describing: type(of: child.value))
        return typeName.contains("Published<")
    }

    #expect(
        published.isEmpty,
        """
        运行时容器发布了 @Published 属性：\(published.map { String(describing: type(of: $0.value)) }).
        写入这些属性会触发 SwiftUI invalidation，重新打开底部锚点 Preference 反馈环。
        """
    )
}
