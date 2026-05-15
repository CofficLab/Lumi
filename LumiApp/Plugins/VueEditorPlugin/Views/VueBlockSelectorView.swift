import Foundation
import SwiftUI

/// Vue SFC 区块快速切换视图
///
/// 在编辑器底部或 Rail 区域提供一个紧凑的区块切换栏：
/// - 显示当前文件包含的区块（Template / Script / Style）
/// - 点击区块按钮快速跳转
/// - 高亮当前光标所在区块
/// - 显示区块属性（setup, scoped, lang）
///
/// 配合 `VueCommandContributor` 的 ⌘+1/2/3 快捷键使用。
struct VueBlockSelectorView: View {
    /// 区块信息
    struct BlockItem: Identifiable {
        let id: String
        let type: SFCBlockType
        let attributes: String
        let startLine: Int   // 0-based
        let endLine: Int
        let isCurrentBlock: Bool
    }

    let blocks: [BlockItem]
    let onSelect: (_ blockType: SFCBlockType) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(blocks) { block in
                blockButton(block)
            }
        }
        .frame(height: 28)
        .background(.bar)
    }

    // MARK: - Block Button

    private func blockButton(_ block: BlockItem) -> some View {
        Button {
            onSelect(block.type)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: block.type.systemImage)
                    .font(.system(size: 10))

                Text(block.type.tagName)
                    .font(.system(size: 11, weight: .medium))

                if !block.attributes.isEmpty {
                    Text(block.attributes)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(block.isCurrentBlock ? Color.accentColor : .secondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                block.isCurrentBlock
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear
            )
            .overlay(alignment: .bottom) {
                if block.isCurrentBlock {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Factory

    /// 从 SFC 区块列表构建选择器数据
    static func items(
        from blocks: [SFCBlock],
        cursorLine: Int
    ) -> [BlockItem] {
        blocks.map { block in
            let isCurrent = cursorLine >= block.startLine && cursorLine <= block.endLine
            let attrs = blockAttributes(block)

            return BlockItem(
                id: "block-\(block.type.rawValue)",
                type: block.type,
                attributes: attrs,
                startLine: block.startLine,
                endLine: block.endLine,
                isCurrentBlock: isCurrent
            )
        }
    }

    private static func blockAttributes(_ block: SFCBlock) -> String {
        var parts: [String] = []
        if block.isSetup { parts.append("setup") }
        if block.isScoped { parts.append("scoped") }
        if block.isModule { parts.append("module") }
        if let lang = block.lang { parts.append(lang) }
        return parts.joined(separator: ", ")
    }
}
