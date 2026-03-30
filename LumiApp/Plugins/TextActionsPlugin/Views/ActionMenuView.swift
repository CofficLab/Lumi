import SwiftUI
import AppKit

struct ActionMenuView: View {
    let text: String
    let onAction: (TextActionType) -> Void

    @State private var hoveredAction: TextActionType? = nil

    // App 信息
    private let appIcon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    private let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Lumi"
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

    var body: some View {
        VStack(spacing: 8) {
            // App 信息头部
            HStack(spacing: 8) {
                // App 图标
                AppImageThumbnail(
                    image: Image(nsImage: appIcon),
                    size: CGSize(width: 24, height: 24),
                    shape: .none
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(appName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppUI.Color.semantic.textPrimary)

                    Text("版本 \(appVersion)")
                        .font(.caption2)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(AppUI.Color.semantic.primary.opacity(0.1))
            .cornerRadius(AppUI.Radius.sm)

            Divider()
                .background(AppUI.Color.semantic.textTertiary.opacity(0.2))

            // 操作按钮
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
                        .foregroundColor(hoveredAction == action ? AppUI.Color.semantic.primary : AppUI.Color.semantic.textPrimary)
                        .frame(width: 50, height: 25)
                        .contentShape(Rectangle())
                        .background(hoveredAction == action ? AppUI.Color.semantic.primary.opacity(0.2) : SwiftUI.Color.clear)
                    }
                    .buttonStyle(.plain)
                    .appSurface(style: .glass, cornerRadius: AppUI.Radius.sm)
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
        }
        .padding(8)
        .appSurface(style: .glass, cornerRadius: AppUI.Radius.sm)
    }
}

#Preview {
    ActionMenuView(text: "测试", onAction: {_ in })
}
