import SwiftUI
import AppKit

struct ActionMenuView: View {
    let text: String
    let onAction: (TextActionType) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(TextActionType.allCases) { action in
                Button(action: {
                    onAction(action)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: action.icon)
                            .font(.system(size: 16))
                        Text(action.title)
                            .font(.caption)
                    }
                    .frame(width: 50, height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                .cornerRadius(8)
                .onHover { isHovering in
                    if isHovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .padding(8)
        .background(EffectView(material: .popover, blendingMode: .behindWindow))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

// Helper for visual effect background
struct EffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
