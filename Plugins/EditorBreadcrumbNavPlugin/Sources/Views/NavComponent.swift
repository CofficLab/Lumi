import LumiCoreKit
import LumiUI
import SwiftUI

// MARK: - Nav Component

/// 单个面包屑路径段组件
public struct NavComponent: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let item: BreadcrumbItem
    public let isLastItem: Bool
    @Binding var truncatedCrumbWidth: CGFloat?
    public let onSelectFile: (URL) -> Void

    @State private var isHovering = false
    @State private var isSiblingPopoverPresented = false

    public var body: some View {
        HStack(spacing: 0) {
            Button {
                isSiblingPopoverPresented.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: BreadcrumbNavIconStyle.iconName(for: item))
                        .font(.appMicro)
                        .foregroundColor(BreadcrumbNavIconStyle.iconColor(for: item, theme: theme))

                    Text(item.name)
                        .font(isLastItem ? .appMicroEmphasized : .appMicro)
                        .foregroundColor(isLastItem ? theme.textPrimary : theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .appSurface(
                    style: .custom(hoverBackground),
                    cornerRadius: 4,
                    borderColor: isSiblingPopoverPresented ? theme.primary.opacity(0.3) : Color.clear
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isSiblingPopoverPresented, arrowEdge: .bottom) {
                MenuContent(
                    siblings: item.siblings,
                    currentURL: item.url,
                    onSelectFile: { url in
                        isSiblingPopoverPresented = false
                        onSelectFile(url)
                    }
                )
                .frame(minWidth: 220)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: 200)
            .frame(
                maxWidth: isHovering || isLastItem ? nil : truncatedCrumbWidth,
                alignment: .leading
            )
            .mask(
                LinearGradient(
                    gradient: Gradient(
                        stops: truncatedCrumbWidth == nil || isHovering
                            ? [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 1),
                            ]
                            : [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.8),
                                .init(color: .clear, location: 1),
                            ]
                    ),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipped()
            .onHover { isHovering = $0 }

            // 分隔箭头
            if !isLastItem {
                chevronView
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Chevron

    @ViewBuilder
    private var chevronView: some View {
        HStack(spacing: 0) {
            if isHovering {
                VStack(spacing: 1) {
                    Image(systemName: "chevron.up")
                    Image(systemName: "chevron.down")
                }
                .font(.appMicroEmphasized)
                .foregroundColor(theme.textTertiary)
                .padding(.top, 0.5)
            } else {
                Image(systemName: "chevron.compact.right")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textTertiary)
                    .scaleEffect(x: 1.30, y: 1.0, anchor: .center)
                    .imageScale(.large)
            }
        }
        .padding(.trailing, 2)
    }

    // MARK: - Hover Background

    private var hoverBackground: Color {
        guard isHovering else { return .clear }
        return theme.textPrimary.opacity(0.06)
    }
}
