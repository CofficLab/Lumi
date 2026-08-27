import SwiftUI

// MARK: - Hex Color

extension Color {
    /// 从十六进制字符串构造颜色（支持 #rgb / #rrggbb / #rrggbbaa）。失败返回 nil。
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.allSatisfy({ $0.isHexDigit }), hex.count == 3 || hex.count == 6 || hex.count == 8 else { return nil }
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        var rgba: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgba)
        let r, g, b, a: Double
        switch hex.count {
        case 6:
            r = Double((rgba >> 16) & 0xFF) / 255
            g = Double((rgba >> 8) & 0xFF) / 255
            b = Double(rgba & 0xFF) / 255
            a = 1
        case 8:
            r = Double((rgba >> 24) & 0xFF) / 255
            g = Double((rgba >> 16) & 0xFF) / 255
            b = Double((rgba >> 8) & 0xFF) / 255
            a = Double(rgba & 0xFF) / 255
        default:
            return nil
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Node View

/// 单个思维导图节点（圆角矩形 + 文本，支持选中与就地编辑）。
struct MindMapNodeView: View {
    let node: MindMapNode
    let size: CGSize
    let isRoot: Bool
    let isSelected: Bool
    let isEditing: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onCommit: (String) -> Void

    @State private var draft: String

    init(
        node: MindMapNode,
        size: CGSize,
        isRoot: Bool,
        isSelected: Bool,
        isEditing: Bool,
        onTap: @escaping () -> Void,
        onDoubleTap: @escaping () -> Void,
        onCommit: @escaping (String) -> Void
    ) {
        self.node = node
        self.size = size
        self.isRoot = isRoot
        self.isSelected = isSelected
        self.isEditing = isEditing
        self.onTap = onTap
        self.onDoubleTap = onDoubleTap
        self.onCommit = onCommit
        _draft = State(initialValue: node.text)
    }

    var body: some View {
        Group {
            if isEditing {
                TextField(MindMapLocalization.string("Node text"), text: $draft, onCommit: { onCommit(draft) })
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
            } else {
                Text(node.text.isEmpty ? " " : node.text)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }
        }
        .frame(minWidth: max(size.width, 64), idealWidth: max(size.width, 64), maxWidth: 240, minHeight: size.height, maxHeight: size.height)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(isRoot ? 0.12 : 0.06), radius: isRoot ? 4 : 2, y: isRoot ? 2 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(count: 2, perform: onDoubleTap)
        .onTapGesture(count: 1, perform: onTap)
        // 进入编辑态时刷新草稿。
        .onChange(of: isEditing) { _, newValue in
            if newValue { draft = node.text }
        }
    }

    private var backgroundColor: Color {
        if let hex = node.color, let color = Color(hex: hex) { return color.opacity(0.9) }
        if isRoot { return Color.accentColor.opacity(0.95) }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        if isSelected { return .accentColor }
        if let hex = node.color, Color(hex: hex) != nil { return .clear }
        return Color.secondary.opacity(0.35)
    }
}
