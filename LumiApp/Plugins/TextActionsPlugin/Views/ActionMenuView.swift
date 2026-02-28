import SwiftUI
import AppKit

struct ActionMenuView: View {
    let text: String
    let onAction: (TextActionType) -> Void

    @State private var hoveredAction: TextActionType? = nil

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TextActionType.allCases) { action in
                Button(action: {
                    onAction(action)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: action.icon)
                            .font(.system(size: 12))
                        Text(action.title)
                            .font(.caption)
                    }
                    .foregroundColor(hoveredAction == action ? DesignTokens.Color.semantic.primary : DesignTokens.Color.semantic.textPrimary)
                    .frame(width: 50, height: 25)
                    .contentShape(Rectangle())
                    .background(hoveredAction == action ? DesignTokens.Color.semantic.primary.opacity(0.2) : SwiftUI.Color.clear)
                }
                .buttonStyle(.plain)
                .background(DesignTokens.Material.glass)
                .cornerRadius(DesignTokens.Radius.sm)
                .onHover { isHovering in
                    hoveredAction = isHovering ? action : nil
                    if isHovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .padding(4)
        .background(DesignTokens.Material.glass)
        .cornerRadius(DesignTokens.Radius.sm)
    }
}

#Preview {
    ActionMenuView(text: "测试", onAction: {_ in })
}
