import AppKit
import Foundation
import Testing
@testable import PluginMessageListStandard

/// 消息列表视图的**状态生命周期**回归测试。
///
/// ## 复现的缺陷
///
/// `ListV2View` 把三个**有状态**的引用类型对象用 `let` 声明为普通存储属性：
///
/// ```swift
/// private let atBottomBox = AtBottomBox()
/// private let scrollCoordinator = MessageListScrollCoordinator()
/// private let bottomScrollController = ScrollViewBottomController()
/// ```
///
/// SwiftUI 的 struct 存储属性初始化表达式**在每次 `init` 调用时都会执行**。
/// 而 `ListV2View` 是由宿主在 body 里生产的：
///
/// ```swift
/// // ProviderChatSection/.../DefaultChatSectionProviding.swift
/// item.makeView()   // → AnyView(ListV2View(...))  → 走 ListV2View.init
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
/// ## 为什么用 Mirror 而不是加生产代码的观察缝
///
/// Mirror 可以在**不改动任何生产代码**的前提下读到 struct 的存储属性，
/// 于是「复现」与「修复」被彻底分开：本文件只描述不变式，修复后依然有效。
/// 同一份 `ListV2View` 里 `initialPositionGate` 用的是 `@StateObject`
/// （SwiftUI 按视图 identity 缓存实例），它就是正确写法的对照。
@MainActor
private func makeListV2View() -> ListV2View {
    let services = MessageListServices(
        conversations: nil,
        conversationState: nil,
        developerModeState: DeveloperModeStateViewModel(),
        messages: nil,
        rendering: nil,
        streaming: nil,
        toolManager: nil,
        agentTurn: nil,
        promptSuggestions: nil,
        promptSuggestionExecutor: nil,
        project: nil,
        toolbar: nil,
        chat: nil
    )
    return ListV2View(
        services: services,
        developerModeState: services.developerModeState,
        viewModel: ListV2ViewModel(services: services)
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

/// 按 label 取出视图存储的类实例。
private func storedClassInstance(_ view: Any, _ label: String) -> AnyObject? {
    for child in Mirror(reflecting: view).children where child.label == label {
        guard Mirror(reflecting: child.value).displayStyle == .class else { return nil }
        return child.value as AnyObject
    }
    return nil
}

// MARK: - 不变式：不得用普通存储属性持有引用类型状态

/// `ListV2View` 不得用**普通存储属性**（非 property wrapper 承载）持有引用类型。
///
/// - Important: 这条是根因不变式。只要有任何一个引用类型对象用普通存储属性
///   持有，宿主每次重绘就会重建它，状态必然丢失。
///   `@StateObject` / `@State` 的 backing storage（label 以 `_` 开头）不受影响，
///   因为 SwiftUI 按视图 identity 缓存它们。
@MainActor
@Test("消息列表视图：不得用普通存储属性持有引用类型状态")
func listViewMustNotHoldReferenceStateInPlainStoredProperty() {
    let offenders = plainClassStorages(of: makeListV2View())

    #expect(
        offenders.isEmpty,
        """
        这些存储属性是引用类型且不由 property wrapper 承载：\(offenders).
        宿主每次重绘都会重新 init 视图并把它们全部重建，\
        滚动序号、是否在底部、滚动视图绑定这些状态随之清零。
        """
    )
}

// MARK: - 行为后果：重建后运行时状态必须仍是同一实例

/// 两次构造视图（等价于宿主两次重绘）必须复用**同一批**运行时状态实例。
@MainActor
@Test("消息列表视图：重建后运行时状态对象必须仍是同一实例")
func listViewRuntimeStateSurvivesReconstruction() {
    let first = makeListV2View()
    let second = makeListV2View()

    for label in ["atBottomBox", "scrollCoordinator", "bottomScrollController"] {
        let firstObject = storedClassInstance(first, label)
        let secondObject = storedClassInstance(second, label)

        guard let firstObject, let secondObject else {
            Issue.record("视图上找不到存储属性 \(label)，无法验证其生命周期")
            continue
        }
        #expect(
            ObjectIdentifier(firstObject) == ObjectIdentifier(secondObject),
            "\(label) 在视图重建后被换成了新实例，它攒的状态（滚动序号 / 底部标记 / 滚动视图绑定）全部丢失"
        )
    }
}

/// 「用户是否在底部」不得在视图重建后被重置回 `true`。
///
/// 这是用户可直接感知的后果：用户已经上滚查看历史，视图一重建标记就变回
/// `true`，随后新消息到达时 `ListV2View` 会把列表强行拉回底部。
@MainActor
@Test("消息列表视图：重建后「是否在底部」标记不得被重置")
func atBottomMarkerSurvivesReconstruction() {
    let first = makeListV2View()
    guard let box = storedClassInstance(first, "atBottomBox") as? AtBottomBox else {
        Issue.record("视图上找不到 atBottomBox 存储属性")
        return
    }

    box.value = false // 模拟用户向上滚动离开底部

    let second = makeListV2View()
    guard let rebuiltBox = storedClassInstance(second, "atBottomBox") as? AtBottomBox else {
        Issue.record("视图上找不到 atBottomBox 存储属性")
        return
    }

    #expect(
        rebuiltBox.value == false,
        "用户上滑后的底部标记在视图重建后被重置为 \(rebuiltBox.value)，流式跟随滚动会在用户已经上滚时继续把列表拉回底部"
    )
}

/// 滚动视图控制器在视图重建后必须仍然绑定着滚动视图。
///
/// 这是「切换会话后首屏定位不收敛」的直接原因：
/// `MessageListScrollCoordinator.prepareInitialBottom` 只在
/// `controller.isAttached == true` 时才进入 `settleBottom` 收敛循环；
/// 控制器一旦被换新（`scrollView` 弱引用为 nil），首屏定位就退化成
/// 「只 `scrollTo` 一次」，而 `List` 的行是逐帧 materialize 的——
/// 底部锚点往往还没物化完，遮罩撤了但列表停在半路。
@MainActor
@Test("消息列表视图：重建后底部控制器不得丢失滚动视图绑定")
func bottomControllerKeepsScrollViewBindingAcrossReconstruction() {
    let first = makeListV2View()
    guard let firstController = storedClassInstance(first, "bottomScrollController")
        as? ScrollViewBottomController
    else {
        Issue.record("视图上找不到 bottomScrollController 存储属性")
        return
    }

    // 给第一个控制器绑定一个真实滚动视图，模拟 tracker 完成 attach。
    let host = NSScrollView()
    firstController.attachForTesting(to: host)
    #expect(firstController.isAttached)

    let second = makeListV2View()
    guard let rebuiltController = storedClassInstance(second, "bottomScrollController")
        as? ScrollViewBottomController
    else {
        Issue.record("视图上找不到 bottomScrollController 存储属性")
        return
    }

    #expect(
        rebuiltController.isAttached,
        "底部控制器在视图重建后丢失了滚动视图绑定，首屏定位会退化为「只滚一次、不做几何收敛」"
    )
}
