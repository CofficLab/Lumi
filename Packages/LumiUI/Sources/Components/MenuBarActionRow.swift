import SwiftUI

/// 菜单栏弹窗操作行，与防休眠等插件快捷菜单样式一致。
public struct MenuBarActionRow: View {
    private let titleKey: LocalizedStringKey?
    private let titleText: String?
    let icon: String
    let color: Color
    var isSelected: Bool
    var showCheckmark: Bool?
    let action: () -> Void

    @State private var isHovering = false

    public init(
        _ title: LocalizedStringKey,
        icon: String,
        color: Color,
        isSelected: Bool = false,
        showCheckmark: Bool? = nil,
        action: @escaping () -> Void
    ) {
        titleKey = title
        titleText = nil
        self.icon = icon
        self.color = color
        self.isSelected = isSelected
        self.showCheckmark = showCheckmark
        self.action = action
    }

    public init(
        title: String,
        icon: String,
        color: Color,
        isSelected: Bool = false,
        showCheckmark: Bool? = nil,
        action: @escaping () -> Void
    ) {
        titleKey = nil
        titleText = title
        self.icon = icon
        self.color = color
        self.isSelected = isSelected
        self.showCheckmark = showCheckmark
        self.action = action
    }

    private var shouldShowCheckmark: Bool {
        if let showCheckmark {
            return showCheckmark
        }
        return isSelected
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isHovering ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF") : color)
                    .frame(width: 18)

                Group {
                    if let titleKey {
                        Text(titleKey)
                    } else if let titleText {
                        Text(verbatim: titleText)
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(isHovering ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF") : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                Spacer()

                if shouldShowCheckmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isHovering ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF") : color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Rectangle()
                .fill(isHovering ? Color(hex: "7C6FFF").opacity(0.2) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
