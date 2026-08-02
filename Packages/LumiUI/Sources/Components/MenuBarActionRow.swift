import SwiftUI

/// 菜单栏弹窗操作行，与防休眠等插件快捷菜单样式一致。
public struct MenuBarActionRow: View {
    @LumiTheme private var theme

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
                    .foregroundColor(isHovering ? theme.textPrimary : color)
                    .frame(width: 18)

                Group {
                    if let titleKey {
                        Text(titleKey)
                    } else if let titleText {
                        Text(verbatim: titleText)
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(isHovering ? theme.textPrimary : theme.textSecondary)

                Spacer()

                if shouldShowCheckmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isHovering ? theme.textPrimary : color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Rectangle()
                .fill(isHovering ? theme.primary.opacity(0.18) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
