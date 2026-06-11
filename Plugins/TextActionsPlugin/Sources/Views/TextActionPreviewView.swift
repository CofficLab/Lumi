import SwiftUI
import LumiUI

/// 显示文本选择菜单的实时预览效果。
public struct TextActionPreviewView: View {
    public let isEnabled: Bool

    public var body: some View {
        VStack(spacing: 20) {
            Text("Preview", bundle: .module)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            ZStack {
                // Document background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Material.regularMaterial)
                    .frame(width: 220, height: 160)

                // Mock content
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "98989E").opacity(0.2))
                        .frame(width: 180, height: 8)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "98989E").opacity(0.2))
                        .frame(width: 160, height: 8)

                    HStack(spacing: 0) {
                        Text("Select ", bundle: .module)
                            .font(.system(size: 12))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                        Text("this text", bundle: .module)
                            .font(.system(size: 12))
                            .padding(.horizontal, 2)
                            .background(isEnabled ? Color(hex: "7C6FFF").opacity(0.3) : SwiftUI.Color.clear)
                            .foregroundColor(isEnabled ? Color(hex: "7C6FFF") : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                            .overlay(
                                GeometryReader { _ in
                                    if isEnabled {
                                        MockActionMenu()
                                            .offset(x: -20, y: -60)
                                    }
                                }
                            )

                        Text(" to see.", bundle: .module)
                            .font(.system(size: 12))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "98989E").opacity(0.2))
                        .frame(width: 140, height: 8)
                }
            }
        }
        .padding()
    }
}

// MARK: - 模拟菜单视图

public struct MockActionMenu: View {
    public var body: some View {
        HStack(spacing: 8) {
            ForEach(TextActionType.allCases) { action in
                VStack(spacing: 4) {
                    Image(systemName: action.icon)
                        .font(.system(size: 14))
                    Text(action.title)
                        .font(.caption2)
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                }
                .frame(width: 44, height: 44)
                .appSurface(style: .glass, cornerRadius: 8)
            }
        }
        .padding(4)
        .appSurface(style: .glass, cornerRadius: 16)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
