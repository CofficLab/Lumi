import SwiftUI
import LumiUI
import AppKit
import LumiCoreKit

public struct ActionMenuView: View {
    public let text: String
    public let onAction: (TextActionType) -> Void

    @State private var hoveredAction: TextActionType? = nil

    // App 信息
    private let appIcon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    private let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Lumi"
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

    public var body: some View {
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
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                    Text(String(format: LumiPluginLocalization.string("Version %@", bundle: .module), appVersion))
                        .font(.caption2)
                        .foregroundColor(Color(hex: "98989E"))
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(hex: "7C6FFF").opacity(0.1))
            .cornerRadius(8)

            Divider()
                .background(Color(hex: "98989E").opacity(0.2))

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
                        .foregroundColor(hoveredAction == action ? Color(hex: "7C6FFF") : Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                        .frame(width: 50, height: 25)
                        .contentShape(Rectangle())
                        .background(hoveredAction == action ? Color(hex: "7C6FFF").opacity(0.2) : SwiftUI.Color.clear)
                    }
                    .buttonStyle(.plain)
                    .appSurface(style: .glass, cornerRadius: 8)
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
        .appSurface(style: .glass, cornerRadius: 8)
    }
}

#Preview {
    ActionMenuView(text: "测试", onAction: {_ in })
}
