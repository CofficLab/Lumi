import CoreGraphics

// MARK: - 访问层

/// divider 位置的访问层。
///
/// 视图层不直接读写内核或磁盘，而是通过此闭包桥接与 `LumiLayoutState` 交互：
/// - `readInitialPosition`: 从内核状态读取上一次保存的位置（无值时返回 nil，由调用方回退到默认值）
/// - `persist`: 把用户拖拽后的位置写回内核（内核变更会发通知，由插件负责落盘）
///
/// 这样 `SplitDividerPersistenceView`（一个 NSView）无需持有 `ObservableObject`，
/// 也不依赖 SwiftUI 的观察机制，保持与 AppKit 的交互方式不变。
///
/// 两个闭包均标记 `@MainActor`，因为它们最终调用 `LumiLayoutState`（`@MainActor`）的方法。
public struct SplitDividerAccess {
    public let readInitialPosition: @MainActor () -> CGFloat?
    public let persist: @MainActor (CGFloat) -> Void
    /// 用于在日志中描述该角色的可读标签，例如 `railDivider[LumiEditor]`。
    public let labelForLog: @MainActor () -> String

    public init(
        readInitialPosition: @MainActor @escaping () -> CGFloat?,
        persist: @MainActor @escaping (CGFloat) -> Void,
        labelForLog: @MainActor @escaping () -> String
    ) {
        self.readInitialPosition = readInitialPosition
        self.persist = persist
        self.labelForLog = labelForLog
    }
}

// MARK: - 角色

/// 描述一个分栏 divider 位置的角色，用于在视图层语义化地选择读写哪一类位置。
///
/// 纯值类型（无 AppKit 依赖），故可被 `LumiCoreKitTests` 直接单元测试。
/// 视图层的 ghost NSView 通过 `makeAccess(layoutState:)` 拿到读写桥接，
/// 其余纯属性（默认位置、轴向、三栏参与度等）也都在此枚举上。
public enum SplitDividerRole: Equatable {
    case rail(viewContainerID: String)
    case bottomPanel(viewContainerID: String)
    case chatSection(viewContainerID: String, layout: LumiChatSectionLayout)

    /// 该角色关联的视图容器 ID（从任意 case 提取）。
    public var viewContainerID: String {
        switch self {
        case .rail(let id), .bottomPanel(let id), .chatSection(let id, _):
            return id
        }
    }

    /// 是否在多层嵌套 NSSplitView 的候选中优先选面积**最大**的那一层。
    ///
    /// `chatSection` 挂在最外层（Panel | Chat）→ 取最大；
    /// `rail` / `bottomPanel` 挂在内层 → 取最小。详见视图层 `pickByRole` 的注释。
    public var prefersLargestCandidate: Bool {
        if case .chatSection = self { return true }
        return false
    }

    /// 基于该角色与内核 `layoutState` 构造读写桥接。
    @MainActor
    public func makeAccess(layoutState: LumiLayoutState) -> SplitDividerAccess {
        switch self {
        case let .rail(viewContainerID):
            return SplitDividerAccess(
                readInitialPosition: { layoutState.storedRailDivider(for: viewContainerID) },
                persist: { layoutState.setRailDivider($0, for: viewContainerID) },
                labelForLog: { "railDivider[\(viewContainerID)]" }
            )
        case let .bottomPanel(viewContainerID):
            return SplitDividerAccess(
                readInitialPosition: { layoutState.storedBottomPanelDivider(for: viewContainerID) },
                persist: { layoutState.setBottomPanelDivider($0, for: viewContainerID) },
                labelForLog: { "bottomPanelDivider[\(viewContainerID)]" }
            )
        case let .chatSection(viewContainerID, layout):
            return SplitDividerAccess(
                readInitialPosition: { layoutState.storedChatSectionDivider(for: viewContainerID, layout: layout) },
                persist: { layoutState.setChatSectionDivider($0, for: viewContainerID, layout: layout) },
                labelForLog: { "chatSectionDivider[\(viewContainerID).\(layout.persistenceKeySuffix)]" }
            )
        }
    }

    /// 首次显示且无持久化值时的回退位置（轴向无关，由 split view 自己的 bounds 决定最终生效值）。
    public func defaultPosition() -> CGFloat {
        switch self {
        case .rail:
            return 240
        case .bottomPanel:
            return 400
        case .chatSection(_, let layout):
            return layout.idealWidth
        }
    }

    /// 该角色期望的 NSSplitView 轴向。
    ///
    /// 返回值语义直接对齐 `NSSplitView.isVertical`，供消歧过滤做相等比较。
    /// 注意命名陷阱：`NSSplitView.isVertical == true` 表示**垂直分隔线**（左右分栏，即 SwiftUI 的 HSplitView）；
    /// `== false` 表示水平分隔线（上下分栏，即 VSplitView）。
    ///
    /// 用于在多层嵌套 NSSplitView 中消歧，避免幽灵 NSView 绑错层级：
    /// - `rail` / `chatSection` 挂在 HSplitView 上 → `isVertical == true` → 返回 `true`
    /// - `bottomPanel` 挂在 VSplitView 上 → `isVertical == false` → 返回 `false`
    public func expectsVerticalSplit() -> Bool {
        switch self {
        case .rail, .chatSection:
            return true   // HSplitView：左右分栏，分隔线垂直
        case .bottomPanel:
            return false  // VSplitView：上下分栏，分隔线水平
        }
    }

    /// 是否参与"rail / middle / chat"水平三栏宽度日志。
    /// - `rail` / `chatSection`：是
    /// - `bottomPanel`：否（影响的是垂直高度，不在三栏中）
    public var participatesInHorizontalThreeColumns: Bool {
        switch self {
        case .rail, .chatSection: return true
        case .bottomPanel: return false
        }
    }
}
