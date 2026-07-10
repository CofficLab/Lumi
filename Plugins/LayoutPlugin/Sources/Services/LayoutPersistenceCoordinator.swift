import CoreGraphics
import LumiCoreKit
import os

/// 布局持久化协调器
///
/// 仅负责从磁盘读取已保存的布局状态并写入 `LumiCore.layoutState`。
/// 事件监听和持久化写入由 `LayoutPersistenceAnchor` 视图处理。
@MainActor
final class LayoutPersistenceCoordinator {
    static let shared = LayoutPersistenceCoordinator()
    static let verbose = true
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout.coordinator")
    private static let t = "[LayoutPersistenceCoordinator] "

    private init() {}

    /// 从磁盘恢复布局状态到内核
    func restore() {
        guard let state = LumiCore.layoutState else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)LumiCore.layoutState 未初始化，跳过恢复")
            }
            return
        }
        restore(into: state, from: LayoutPluginLocalStore.shared)
    }

    /// 从指定 store 恢复布局状态到指定的 layoutState（可注入，便于测试）。
    func restore(into state: LumiLayoutState, from store: LayoutPluginLocalStore) {
        var restored: [String] = []

        if let id = store.loadActiveViewContainerID() {
            state.activeViewContainerID = id
            restored.append("activeViewContainerID=\(id)")
        }
        if let tabId = store.loadSelectedAgentSidebarTabId() {
            state.activeRailTabID = tabId
            restored.append("activeRailTabID=\(tabId)")
        }
        if let bottomTabId = store.string(forKey: LayoutStorageKey.activeBottomTabID) {
            state.activeBottomTabID = bottomTabId
            restored.append("activeBottomTabID=\(bottomTabId)")
        }
        if let visible = store.loadBottomPanelVisible() {
            state.bottomPanelVisible = visible
            restored.append("bottomPanelVisible=\(visible)")
        }
        if let visible = store.loadContentPanelVisible() {
            state.chatSectionVisible = visible
            restored.append("chatSectionVisible=\(visible)")
        }

        restoreSplitDimensions(into: state, from: store, restored: &restored)

        if Self.verbose {
            if restored.isEmpty {
                Self.logger.info("\(Self.t)磁盘无已保存布局，使用默认值")
            } else {
                Self.logger.info("\(Self.t)已从磁盘恢复: \(restored.joined(separator: ", "))")
            }
        }

        // DEBUG: 打印恢复后 layoutState 中实际的 chatSectionWidths 值
        #if DEBUG
        let editorNarrow = state.storedChatSectionWidth(for: "LumiEditor", layout: .narrow)
        let editorWide = state.storedChatSectionWidth(for: "LumiEditor", layout: .wide)
        Self.logger.info("\(Self.t)[DEBUG restore] after restore, storedChatSectionWidth(LumiEditor.narrow)=\(editorNarrow.map { String(describing: $0) } ?? "nil"), storedChatSectionWidth(LumiEditor.wide)=\(editorWide.map { String(describing: $0) } ?? "nil")")
        #endif
    }

    /// 从 store 的 splitDimensions 字典中按 key 前缀回填各分栏尺寸到 layoutState。
    /// 回填使用不发通知的 `restoreXxx` 方法，避免启动时触发落盘。
    private func restoreSplitDimensions(
        into state: LumiLayoutState,
        from store: LayoutPluginLocalStore,
        restored: inout [String]
    ) {
        let dimensions = store.loadSplitDimensions()
        guard !dimensions.isEmpty else {
            if Self.verbose {
                Self.logger.info("\(Self.t)[restoreSplitDimensions] dimensions is empty, skipping")
            }
            return
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)[restoreSplitDimensions] found \(dimensions.count) keys: \(dimensions.keys.sorted().joined(separator: ", "))")
        }

        let railPrefix = "Layout.Width."
        let railSuffix = ".Rail"
        let chatPrefix = "Layout.Width."
        let chatInfix = ".ChatSection."
        let bottomPrefix = "Layout.Height."
        let bottomSuffix = ".BottomPanel"

        for (key, value) in dimensions {
            let cgValue = CGFloat(value)
            // Rail 宽度: Layout.Width.<id>.Rail
            if key.hasPrefix(railPrefix), key.hasSuffix(railSuffix) {
                let inner = String(key.dropFirst(railPrefix.count).dropLast(railSuffix.count))
                guard !inner.isEmpty else { continue }
                state.restoreRailWidth(cgValue, for: inner)
                restored.append("railWidth[\(inner)]=\(cgValue)")
                continue
            }
            // 聊天区宽度: Layout.Width.<id>.ChatSection.<layout>
            if key.hasPrefix(chatPrefix), key.contains(chatInfix) {
                let inner = String(key.dropFirst(chatPrefix.count))
                guard let dotRange = inner.range(of: chatInfix) else {
                    if Self.verbose {
                        Self.logger.warning("\(Self.t)[restoreSplitDimensions] chat key parse failed: '\(key)' has no '\(chatInfix)' range in '\(inner)'")
                    }
                    continue
                }
                let containerID = String(inner[..<dotRange.lowerBound])
                let layoutSuffix = String(inner[dotRange.upperBound...])
                guard !containerID.isEmpty,
                      let layout = LumiChatSectionLayout.from(persistenceKeySuffix: layoutSuffix)
                else {
                    if Self.verbose {
                        Self.logger.warning("\(Self.t)[restoreSplitDimensions] chat key parse failed: containerID='\(containerID)', layoutSuffix='\(layoutSuffix)'")
                    }
                    continue
                }
                state.restoreChatSectionWidth(cgValue, for: containerID, layout: layout)
                restored.append("chatSectionWidth[\(containerID).\(layoutSuffix)]=\(cgValue)")
                continue
            }
            // 底部面板高度: Layout.Height.<id>.BottomPanel
            if key.hasPrefix(bottomPrefix), key.hasSuffix(bottomSuffix) {
                let inner = String(key.dropFirst(bottomPrefix.count).dropLast(bottomSuffix.count))
                guard !inner.isEmpty else { continue }
                state.restoreBottomPanelHeight(cgValue, for: inner)
                restored.append("bottomPanelHeight[\(inner)]=\(cgValue)")
                continue
            }

            if Self.verbose {
                Self.logger.info("\(Self.t)[restoreSplitDimensions] key '\(key)' did not match any pattern, skipped")
            }
        }
    }
}
