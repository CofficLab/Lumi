import CoreGraphics

// MARK: - 访问层

/// divider 位置的访问层。
///
/// 视图层不直接读写内核或磁盘，而是通过此闭包桥接与 `LayoutState` 交互：
/// - `readInitialPosition`: 从内核状态读取上一次保存的位置（无值时返回 nil，由调用方回退到默认值）
/// - `persist`: 把用户拖拽后的位置写回内核（内核变更会发通知，由插件负责落盘）
public struct SplitDividerAccess {
    public let readInitialPosition: @MainActor () -> CGFloat?
    public let persist: @MainActor (CGFloat) -> Void
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
public enum SplitDividerRole: Equatable {
    case rail(viewContainerID: String)
    case bottomPanel(viewContainerID: String)
    case chatSection(viewContainerID: String, layout: LumiChatSectionLayout)

    public var viewContainerID: String {
        switch self {
        case let .rail(id), let .bottomPanel(id), let .chatSection(id, _):
            return id
        }
    }

    /// 是否在多层嵌套 NSSplitView 的候选中优先选面积**最大**的那一层。
    public var prefersLargestCandidate: Bool {
        if case .chatSection = self { return true }
        return false
    }

    /// 基于该角色与内核 `layoutState` 构造读写桥接。
    @MainActor
    public func makeAccess(layoutState: LayoutState) -> SplitDividerAccess {
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

    /// 首次显示且无持久化值时的回退位置。
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
    public func expectsVerticalSplit() -> Bool {
        switch self {
        case .rail, .chatSection:
            return true
        case .bottomPanel:
            return false
        }
    }

    /// 是否参与"rail / middle / chat"水平三栏宽度日志。
    public var participatesInHorizontalThreeColumns: Bool {
        switch self {
        case .rail, .chatSection: return true
        case .bottomPanel: return false
        }
    }
}
