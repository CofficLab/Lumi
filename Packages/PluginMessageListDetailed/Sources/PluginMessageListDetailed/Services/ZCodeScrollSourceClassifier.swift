import CoreGraphics
import Foundation

/// V4（ZCode）滚动来源分类器。
///
/// 基准是 ZCode 3.15.1 的 `packages/ui/src/v4/timelineScrollAnchor.ts`：
/// 只有**真实用户滚动输入**可以改变 `following`；程序化贴底、terminal 折叠与
/// virtualizer 测高补偿产生的 scroll 事件只更新几何账目。
///
/// - Important: 事件优先级是 **显式 programmatic > 当前滚动视图上的真实用户
///   输入 > layout**。程序化滚动期间发生的用户输入（哪怕是同一个滚动视图上的）
///   也要被忽略，否则「贴底」与「用户上滚」会在同一帧里互相覆盖。
///
/// - Note: 本类型是**纯逻辑**，不含 AppKit 依赖，因此可以直接单测。
enum ZCodeScrollSourceClassifier {

    /// 一次滚动事件的输入。
    struct Input: Equatable {
        /// 事件种类。
        enum Kind: Equatable {
            /// 滚轮 / 触控板。
            case scrollWheel
            /// 触摸拖动。
            case touch
            /// 键盘。
            case key
            /// 滚动条拖动。
            case scrollbar
            /// 程序化写入 clip bounds。
            case programmatic
            /// 文档高度变化（行物化、异步测高、折叠）。
            case documentFrameChange
            /// live resize。
            case liveResize
            /// 其它布局变化。
            case layout
        }

        /// 事件种类。
        let kind: Kind
        /// 滚轮 / 触摸的纵向增量。
        var deltaY: CGFloat = 0
        /// 键盘事件的按键。
        var key: String = ""
        /// 事件目标是否落在可编辑控件里（输入框）。
        ///
        /// - Important: 输入框内的光标键属于**输入**，不是 timeline 滚动。
        var isEditableTarget: Bool = false
        /// 当前是否处于显式的程序化滚动作用域内。
        var isProgrammaticScopeActive: Bool = false
    }

    /// 分类一次滚动事件。
    static func classify(_ input: Input) -> ZCodeScrollEventSource {        // 优先级 1：显式程序化作用域最高。
        if input.isProgrammaticScopeActive {
            return .programmatic
        }

        switch input.kind {
        case .programmatic:
            return .programmatic
        case .documentFrameChange, .liveResize, .layout:
            return .layout
        case .scrollWheel, .touch, .scrollbar:
            // 优先级 2：真实用户输入（但输入框内的不算）。
            return input.isEditableTarget ? .layout : .user
        case .key:
            guard !input.isEditableTarget else { return .layout }
            return isTimelineScrollKey(input.key) ? .user : .layout
        }
    }

    /// 按键是否属于 timeline 滚动。
    ///
    /// - Note: 上下方向键、PageUp/PageDown、Home/End 与空格都属于滚动；
    ///   其余按键（字母、编辑键等）不属于。
    static func isTimelineScrollKey(_ key: String) -> Bool {
        switch key {
        case "ArrowUp", "ArrowDown", "PageUp", "PageDown", "Home", "End", " ":
            return true
        default:
            return false
        }
    }

    /// 是否接受一次用户事件。
    ///
    /// - Important: 必须同时满足「同一 window」与「同一滚动视图」。
    ///   否则 Rail（侧栏）的滚动会被误当成消息列表的滚动。
    static func shouldAcceptUserEvent(
        eventWindowID: Int,
        targetWindowID: Int,
        eventScrollViewID: Int,
        targetScrollViewID: Int
    ) -> Bool {
        guard eventWindowID == targetWindowID else { return false }
        guard eventScrollViewID == targetScrollViewID else { return false }
        return true
    }
}

/// 滚动来源输入的类型别名。
///
/// - Note: 让调用点可以写成 `ZCodeScrollSourceInput(...)`，
///   读起来比嵌套的 `ZCodeScrollSourceClassifier.Input` 更直接。
typealias ZCodeScrollSourceInput = ZCodeScrollSourceClassifier.Input

/// 程序化滚动的作用域标记。
///
/// - Important: 程序化写入 clip bounds 会**同步**触发
///   `boundsDidChangeNotification`。若不显式标记这段作用域，
///   分类器会把「我们自己写的滚动」当成用户滚动，从而错误地改变 `following`。
///
/// - Note: 用**嵌套计数**而不是布尔值：贴底过程中可能再次触发一轮收敛，
///   内层的 `end` 不能提前解除外层的作用域。
struct ZCodeProgrammaticScrollScope {
    /// 当前嵌套深度。
    private var depth = 0

    /// 是否处于程序化滚动作用域内。
    var isActive: Bool { depth > 0 }

    /// 进入作用域。
    mutating func begin() {
        depth += 1
    }

    /// 离开作用域。
    mutating func end() {
        // 多余的 end 不能让深度变成负数。
        if depth > 0 { depth -= 1 }
    }

    /// 在作用域内执行一段程序化滚动。
    mutating func withScope<T>(_ body: () -> T) -> T {
        begin()
        defer { end() }
        return body()
    }
}
