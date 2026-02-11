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
                    .frame(width: 50, height: 25)
                    .contentShape(Rectangle())
                    .background(hoveredAction == action ? Color.accentColor.opacity(0.2) : Color.clear)
                }
                .buttonStyle(.plain)
                .background(.background.opacity(0.8))
                .cornerRadius(4)
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
        .background(.regularMaterial)
        .cornerRadius(4)
    }
}

#Preview {
    ActionMenuView(text: "测试", onAction: {_ in })
}
