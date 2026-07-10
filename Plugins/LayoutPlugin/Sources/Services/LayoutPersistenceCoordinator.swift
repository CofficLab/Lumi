import CoreGraphics
import LumiCoreKit
import SuperLogKit
import os

/// 布局持久化协调器
///
/// 仅负责从磁盘读取已保存的布局状态并写入 `LumiCore.layoutState`。
/// 事件监听和持久化写入由 `LayoutPersistenceAnchor` 视图处理。
@MainActor
final class LayoutPersistenceCoordinator: SuperLog {
    nonisolated static let emoji = LayoutPlugin.emoji
    nonisolated static let verbose = LayoutPlugin.verbose
    static let shared = LayoutPersistenceCoordinator()

    private init() {}

    /// 从磁盘恢复布局状态到内核
    func restore() {
        guard let state = LumiCore.layoutState else {
            if Self.verbose {
                LayoutPlugin.logger.warning("\(self.t)LumiCore.layoutState 未初始化，跳过恢复")
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

        // 先清掉 v1 旧 key（Width/Height 格式），避免遗留数据堆积。
        cleanupLegacySplitDimensions(in: store)
        restoreSplitDimensions(into: state, from: store, restored: &restored)

        if Self.verbose {
            if restored.isEmpty {
                LayoutPlugin.logger.info("\(self.t)磁盘无已保存布局，使用默认值")
            } else {
                LayoutPlugin.logger.info("\(self.t)已从磁盘恢复: \(restored.joined(separator: ", "))")
            }
        }

        // DEBUG: 打印恢复后 layoutState 中实际的 chatSectionDivider 值
        #if DEBUG
        if Self.verbose {
            let editorNarrow = state.storedChatSectionDivider(for: "LumiEditor", layout: .narrow)
            let editorWide = state.storedChatSectionDivider(for: "LumiEditor", layout: .wide)
            LayoutPlugin.logger.info("\(self.t)[DEBUG restore] after restore, storedChatSectionDivider(LumiEditor.narrow)=\(editorNarrow.map { String(describing: $0) } ?? "nil"), storedChatSectionDivider(LumiEditor.wide)=\(editorWide.map { String(describing: $0) } ?? "nil")")
        }
        #endif
    }

    /// 从 store 的 splitDimensions 字典中按新格式 key 回填各分栏 divider 位置到 layoutState。
    /// 回填使用不发通知的 `restoreXxx` 方法，避免启动时触发落盘。
    private func restoreSplitDimensions(
        into state: LumiLayoutState,
        from store: LayoutPluginLocalStore,
        restored: inout [String]
    ) {
        let dimensions = store.loadSplitDimensions()
        guard !dimensions.isEmpty else {
            if Self.verbose {
                LayoutPlugin.logger.info("\(self.t)[restoreSplitDimensions] dimensions is empty, skipping")
            }
            return
        }

        if Self.verbose {
            LayoutPlugin.logger.info("\(self.t)[restoreSplitDimensions] found \(dimensions.count) keys: \(dimensions.keys.sorted().joined(separator: ", "))")
        }

        // 新格式 key 前缀：Layout.Position.<id>.<role>[.<layoutSuffix>].<dividerIndex>
        // divider index 是最后一个 dot-separated 段，先剥掉它再解析 role。
        let prefix = "Layout.Position."

        for (key, value) in dimensions {
            guard key.hasPrefix(prefix) else { continue }
            let cgValue = CGFloat(value)
            let rest = String(key.dropFirst(prefix.count))

            // 1) 形如 "Rail" / "BottomPanel"：直接以 suffix 匹配
            // 2) 形如 "ChatSection.<layoutSuffix>"：从右往左找 .ChatSection.
            // 两种都需要先剥掉尾部的 ".<dividerIndex>"

            // BottomPanel: 形如 "<id>.BottomPanel.0"
            if let id = extractIDForRole(in: rest, roleSuffix: ".BottomPanel") {
                state.restoreBottomPanelDivider(cgValue, for: id)
                restored.append("bottomPanelDivider[\(id)]=\(cgValue)")
                continue
            }
            // Rail: 形如 "<id>.Rail.0"
            if let id = extractIDForRole(in: rest, roleSuffix: ".Rail") {
                state.restoreRailDivider(cgValue, for: id)
                restored.append("railDivider[\(id)]=\(cgValue)")
                continue
            }
            // ChatSection: 形如 "<id>.ChatSection.<layout>.0"
            if let parsed = extractChatSection(in: rest) {
                state.restoreChatSectionDivider(cgValue, for: parsed.id, layout: parsed.layout)
                restored.append("chatSectionDivider[\(parsed.id).\(parsed.layout.persistenceKeySuffix)]=\(cgValue)")
                continue
            }

            if Self.verbose {
                LayoutPlugin.logger.info("\(self.t)[restoreSplitDimensions] key '\(key)' did not match any pattern, skipped")
            }
        }
    }

    /// 从 "<id>.<role>.0" 格式中提取 id（假设 role 后还有 .<dividerIndex> 后缀）。
    /// 找不到或 id 为空时返回 nil。
    private func extractIDForRole(in rest: String, roleSuffix: String) -> String? {
        // rest 末尾必为 ".<dividerIndex>"，先剥掉
        guard let lastDot = rest.lastIndex(of: ".") else { return nil }
        let body = String(rest[..<lastDot])
        guard body.hasSuffix(roleSuffix) else { return nil }
        let id = String(body.dropLast(roleSuffix.count))
        return id.isEmpty ? nil : id
    }

    /// 从 "<id>.ChatSection.<layoutSuffix>.0" 中解析 (id, layout)。
    /// 找最右侧的 ".ChatSection." 分隔点；前面的部分是 id，后面的最后一段是 layoutSuffix（再剥掉尾部的 divider index）。
    private func extractChatSection(in rest: String) -> (id: String, layout: LumiChatSectionLayout)? {
        let infix = ".ChatSection."
        guard let range = rest.range(of: infix, options: .backwards) else { return nil }
        let id = String(rest[..<range.lowerBound])
        let after = String(rest[range.upperBound...])
        // after 形如 "<layout>.0"
        guard let lastDot = after.lastIndex(of: ".") else { return nil }
        let layoutSuffix = String(after[..<lastDot])
        guard !id.isEmpty,
              let layout = LumiChatSectionLayout.from(persistenceKeySuffix: layoutSuffix)
        else {
            if Self.verbose {
                LayoutPlugin.logger.warning("\(self.t)[restoreSplitDimensions] chat key parse failed: id='\(id)', layoutSuffix='\(layoutSuffix)'")
            }
            return nil
        }
        return (id, layout)
    }

    /// 清理 v1 旧 key（"Layout.Width.*" / "Layout.Height.*"）。
    /// 旧 key 里的值是 pane width/height，与 v2 的 divider position 语义不同，不能直接迁移；
    /// 一次性删除以避免遗留数据堆积。
    private func cleanupLegacySplitDimensions(in store: LayoutPluginLocalStore) {
        let dimensions = store.loadSplitDimensions()
        let legacyPrefixes = ["Layout.Width.", "Layout.Height."]
        let legacyKeys = dimensions.keys.filter { key in
            legacyPrefixes.contains(where: { key.hasPrefix($0) })
        }
        guard !legacyKeys.isEmpty else { return }
        if Self.verbose {
            LayoutPlugin.logger.info("\(self.t)清理 v1 旧分栏尺寸 key: \(legacyKeys.sorted().joined(separator: ", "))")
        }
        for key in legacyKeys {
            store.removeSplitDimension(forKey: key)
        }
    }
}
