import LumiUI
import SwiftUI

// MARK: - Menu Row

/// 面包屑下拉菜单中的单行视图
public struct MenuRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @LumiMotionPreferenceReader private var motionPreference

    public let sibling: BreadcrumbSibling
    public let isCurrent: Bool
    public let onSelectFile: (URL) -> Void

    @State private var isHovering = false

    public var body: some View {
        Button {
            onSelectFile(sibling.url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: BreadcrumbNavIconStyle.iconName(for: sibling))
                    .font(.appMicro)
                    .foregroundColor(BreadcrumbNavIconStyle.iconColor(for: sibling, theme: theme))
                    .frame(width: 14)

                Text(sibling.name)
                    .font(.appCaption)
                    .foregroundColor(isCurrent ? theme.textPrimary : theme.textSecondary)

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.primary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .appSurface(
                style: isCurrent ? .listRowSelected : (isHovering ? .listRowHover : .listRow),
                cornerRadius: 6,
                borderColor: isCurrent ? theme.appSelectedBorder : (isHovering ? theme.appHoverBorder : nil)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering && motionPreference.allowsMotion ? LumiMotion.rowHoverScale : 1)
        .animation(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference), value: isHovering)
        .onHover { hovering in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovering = hovering
            }
        }
    }
}
