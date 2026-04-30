import Foundation
import Combine

/// 管理每个 EditorGroup 对应的独立 EditorState 实例。
///
/// ## 多 EditorState 实例架构
///
/// 每个 leaf group 持有独立的 `EditorState`，这意味着：
/// - split 后的每个分栏可以独立加载文件、编辑、保存
/// - 每个 EditorState 有自己的 LSP 协调器、Provider 和 buffer
/// - 活跃 group 切换时，只需要切换哪个 EditorState 接收全局命令
///
/// ## 配置同步
///
/// UI 配置（字体、主题、Tab 宽度等）通过 sink 从主 EditorState 同步到所有 hosted state，
/// 确保用户在任一分栏修改配置后，所有分栏保持一致。
@MainActor
final class EditorGroupHostStore: ObservableObject {
    private var states: [EditorGroup.ID: EditorState] = [:]
    private var configSyncCancellables: [EditorGroup.ID: AnyCancellable] = [:]

    /// 弱引用主 EditorState（由 EditorRootView 持有），用于配置同步源。
    private weak var primaryState: EditorState?

    func state(for groupID: EditorGroup.ID) -> EditorState {
        if let existing = states[groupID] {
            return existing
        }

        let created = EditorState()
        states[groupID] = created

        // 同步当前配置到新建的 state
        if let primaryState {
            syncConfig(from: primaryState, to: created, groupID: groupID)
        }

        return created
    }

    /// 设置主 EditorState 引用，用于后续配置同步。
    func setPrimaryState(_ state: EditorState) {
        primaryState = state
    }

    /// 获取所有已管理的 EditorState 实例。
    var allStates: [EditorState] {
        Array(states.values)
    }

    func removeState(for groupID: EditorGroup.ID) {
        states.removeValue(forKey: groupID)
        configSyncCancellables.removeValue(forKey: groupID)
    }

    func retainOnly(_ groupIDs: Set<EditorGroup.ID>) {
        let removedIDs = Set(states.keys).subtracting(groupIDs)
        for id in removedIDs {
            configSyncCancellables.removeValue(forKey: id)
        }
        states = states.filter { groupIDs.contains($0.key) }
    }

    /// 将主 EditorState 的当前 UI 配置一次性同步到所有 hosted state。
    func syncConfigToAllHosted(from primaryState: EditorState) {
        for (groupID, hostedState) in states {
            syncConfig(from: primaryState, to: hostedState, groupID: groupID)
        }
    }

    // MARK: - Private

    /// 将配置从主 state 同步到 hosted state，并建立持续监听。
    private func syncConfig(
        from source: EditorState,
        to target: EditorState,
        groupID: EditorGroup.ID
    ) {
        // 一次性同步当前值
        target.fontSize = source.fontSize
        target.tabWidth = source.tabWidth
        target.useSpaces = source.useSpaces
        target.wrapLines = source.wrapLines
        target.showMinimap = source.showMinimap
        target.showGutter = source.showGutter
        target.showFoldingRibbon = source.showFoldingRibbon
        // 主题通过 syncThemeSilently 同步，不触发持久化和通知
        target.syncThemeSilently(source.currentThemeId)

        // 建立持续监听：当主 state 配置变化时，同步到 hosted state
        var cancellable = Set<AnyCancellable>()
        source.$fontSize.sink { [weak target] v in target?.fontSize = v }.store(in: &cancellable)
        source.$tabWidth.sink { [weak target] v in target?.tabWidth = v }.store(in: &cancellable)
        source.$useSpaces.sink { [weak target] v in target?.useSpaces = v }.store(in: &cancellable)
        source.$wrapLines.sink { [weak target] v in target?.wrapLines = v }.store(in: &cancellable)
        source.$showMinimap.sink { [weak target] v in target?.showMinimap = v }.store(in: &cancellable)
        source.$showGutter.sink { [weak target] v in target?.showGutter = v }.store(in: &cancellable)
        source.$showFoldingRibbon.sink { [weak target] v in target?.showFoldingRibbon = v }.store(in: &cancellable)
        source.$currentThemeId.sink { [weak target] v in target?.syncThemeSilently(v) }.store(in: &cancellable)

        configSyncCancellables[groupID] = cancellable.first ?? AnyCancellable({})
    }
}
