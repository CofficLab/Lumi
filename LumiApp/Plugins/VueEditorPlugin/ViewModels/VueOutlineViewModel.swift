import Foundation
import SwiftUI
import Combine
import os

/// Vue 组件大纲视图模型
///
/// 从当前 `.vue` 文件中解析出组件结构信息（区块、Props、Emits、Slots），
/// 并以树形大纲形式展示，支持点击跳转。
///
/// 绑定到 WindowEditorVM 的文档变化自动刷新大纲。
@MainActor
final class VueOutlineViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🌳"
    nonisolated static let verbose: Bool = true
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor.outline-vm"
    )

    // MARK: - Published State

    /// 大纲根节点列表
    @Published var outlineNodes: [OutlineNode] = []

    /// 当前活跃区块
    @Published var activeBlock: SFCBlockType?

    /// 文件路径（用于显示）
    @Published var fileName: String = ""

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 组件信息（如果有）
    @Published var componentInfo: VueComponentInfo?

    // MARK: - Outline Node

    /// 大纲节点
    struct OutlineNode: Identifiable, Sendable {
        let id: String
        let title: String
        let subtitle: String?
        let icon: String
        let line: Int          // 0-based
        let kind: NodeKind
        let children: [OutlineNode]
        let depth: Int
    }

    /// 节点类型
    enum NodeKind: String, Sendable {
        case templateBlock
        case scriptBlock
        case styleBlock
        case prop
        case emit
        case slot
        case section
    }

    // MARK: - 解析

    /// 从 .vue 文件内容生成大纲
    ///
    /// - Parameters:
    ///   - content: .vue 文件完整内容
    ///   - fileName: 文件名（不含路径）
    func parse(content: String, fileName: String) {
        self.fileName = fileName

        let blocks = SFCBlock.parse(from: content)
        var nodes: [OutlineNode] = []

        // 1. 区块节点
        for block in blocks {
            let blockChildren: [OutlineNode] = blockChildren(for: block, content: content)
            let attrs = blockAttributesSummary(block)

            nodes.append(OutlineNode(
                id: "block-\(block.type.rawValue)-\(block.startLine)",
                title: block.type.tagName + attrs,
                subtitle: "\(block.endLine - block.startLine + 1) lines",
                icon: block.type.systemImage,
                line: block.startLine + 1,
                kind: blockKind(block.type),
                children: blockChildren,
                depth: 0
            ))
        }

        // 2. 解析组件信息（Props/Emits/Slots）
        let vueVersion = VueVersionDetector.detect(at: "") // 仅用默认
        let info = VueComponentInfo.parse(
            from: content,
            filePath: fileName,
            vueVersion: vueVersion
        )
        self.componentInfo = info

        self.outlineNodes = nodes
        self.isLoading = false
    }

    /// 更新活跃区块（根据光标位置）
    ///
    /// - Parameter line: 当前光标行（0-based）
    func updateActiveBlock(cursorLine: Int) {
        guard let info = componentInfo else { return }
        let block = SFCBlock.blockAt(line: cursorLine, in: info.blocks)
        activeBlock = block?.type
    }

    // MARK: - Private

    private func blockKind(_ type: SFCBlockType) -> NodeKind {
        switch type {
        case .template: return .templateBlock
        case .script: return .scriptBlock
        case .style: return .styleBlock
        }
    }

    private func blockAttributesSummary(_ block: SFCBlock) -> String {
        var parts: [String] = []
        if block.isSetup { parts.append("setup") }
        if block.isScoped { parts.append("scoped") }
        if block.isModule { parts.append("module") }
        if let lang = block.lang { parts.append(lang) }
        return parts.isEmpty ? "" : " \(parts.joined(separator: ", "))"
    }

    private func blockChildren(for block: SFCBlock, content: String) -> [OutlineNode] {
        var children: [OutlineNode] = []

        switch block.type {
        case .script:
            // Props
            if let info = componentInfo {
                for prop in info.props {
                    children.append(OutlineNode(
                        id: "prop-\(prop.name)",
                        title: prop.name,
                        subtitle: prop.type.rawValue + (prop.isRequired ? " (required)" : " (optional)"),
                        icon: "p.circle",
                        line: block.startLine + 1,
                        kind: .prop,
                        children: [],
                        depth: 1
                    ))
                }
                // Emits
                for emit in info.emits {
                    children.append(OutlineNode(
                        id: "emit-\(emit.name)",
                        title: emit.name,
                        subtitle: "emit",
                        icon: "arrow.up.circle",
                        line: block.startLine + 1,
                        kind: .emit,
                        children: [],
                        depth: 1
                    ))
                }
            }

        case .template:
            // Slots
            if let info = componentInfo {
                for slot in info.slots {
                    children.append(OutlineNode(
                        id: "slot-\(slot.name)",
                        title: "#\(slot.name)",
                        subtitle: slot.isDefault ? "default slot" : "named slot",
                        icon: "square.on.square",
                        line: block.startLine + 1,
                        kind: .slot,
                        children: [],
                        depth: 1
                    ))
                }
            }

        case .style:
            break
        }

        return children
    }
}
