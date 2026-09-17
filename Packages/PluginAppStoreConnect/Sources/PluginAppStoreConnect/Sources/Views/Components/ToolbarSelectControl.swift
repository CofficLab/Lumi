import LumiUI
import SwiftUI

/// 与 Projects 工具栏项目控件保持一致的选择控件。
struct ToolbarSelectControl<Content: View>: View {
    let title: String
    let systemImage: String
    let iconTint: Color?
    let maxTitleWidth: CGFloat
    @ViewBuilder let content: () -> Content

    @LumiTheme private var theme: any LumiUITheme
    @LumiMotionPreferenceReader private var motionPreference
    @State private var isPopoverPresented = false
    @State private var isHovering = false

    init(
        title: String,
        systemImage: String,
        iconTint: Color? = nil,
        maxTitleWidth: CGFloat = 220,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.iconTint = iconTint
        self.maxTitleWidth = maxTitleWidth
        self.content = content
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconTint ?? theme.textPrimary)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: maxTitleWidth)

                Image(systemName: isPopoverPresented ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
            }
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .appSurface(
                style: isHighlighted ? .listRowHover : .listRow,
                cornerRadius: 6,
                borderColor: isHighlighted ? theme.appHoverBorder : nil
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            content()
                .padding(12)
        }
        .onHover { hovering in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovering = hovering
            }
        }
        .animation(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference), value: isHighlighted)
    }

    private var isHighlighted: Bool {
        isHovering || isPopoverPresented
    }
}
