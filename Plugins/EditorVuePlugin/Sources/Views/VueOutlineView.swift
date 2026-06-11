import Foundation
import SwiftUI

/// Vue 组件结构大纲视图
///
/// 以树形结构展示当前 `.vue` 文件的组件信息：
/// - 三大区块 (Template / Script / Style) 及其行范围
/// - Props 列表（名称、类型、是否必填）
/// - Emits 列表
/// - Slots 列表
///
/// 点击节点可跳转到对应行。
struct VueOutlineView: View {
    @ObservedObject var viewModel: VueOutlineViewModel
    let onNavigate: (_ line: Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            header

            Divider()

            // 大纲树
            if viewModel.outlineNodes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.outlineNodes) { node in
                            OutlineNodeRow(
                                node: node,
                                isActive: isActiveNode(node),
                                onTap: { onNavigate(node.line) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text(viewModel.fileName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Spacer()

            if let info = viewModel.componentInfo {
                Text("\(info.props.count)P · \(info.emits.count)E · \(info.slots.count)S")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "curlybraces")
                .font(.system(size: 24))
                .foregroundStyle(.quaternary)
            Text("Open a .vue file to see outline", bundle: .module)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Active Check

    private func isActiveNode(_ node: VueOutlineViewModel.OutlineNode) -> Bool {
        guard let active = viewModel.activeBlock else { return false }
        switch node.kind {
        case .templateBlock: return active == .template
        case .scriptBlock: return active == .script
        case .styleBlock: return active == .style
        default: return false
        }
    }
}

// MARK: - Node Row

private struct OutlineNodeRow: View {
    let node: VueOutlineViewModel.OutlineNode
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // 图标
                Image(systemName: node.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(iconColor)
                    .frame(width: 16)

                // 标题
                Text(node.title)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                // 副标题
                if let subtitle = node.subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, CGFloat(node.depth) * 12 + 8)
            .padding(.trailing, 8)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    private var iconColor: Color {
        switch node.kind {
        case .templateBlock: return .green
        case .scriptBlock: return .blue
        case .styleBlock: return .purple
        case .prop: return .orange
        case .emit: return .cyan
        case .slot: return .pink
        case .section: return .secondary
        }
    }
}
