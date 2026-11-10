import SwiftUI

/// 分组卡片内的设置行：图标 + 标题/描述 + 右侧自定义内容。
///
/// - macOS：桌面三段式布局（20pt 图标 + 标题/小字堆叠 + 行尾控件），并带 hover / 按压反馈。
/// - iOS：iOS 设置行布局（17pt 标题 + footnote 副标题 + 行尾控件），行间带发丝分隔线，
///   行高不小于 44pt，图标缩小并弱化为次要色 —— 与 Settings.app 的行观感一致。
public struct AppSettingRow<Content: View, TitleSuffix: View>: View {
    let title: String
    let description: String?
    let icon: String?
    let leadingColor: Color?
    let titleColor: Color?
    let content: Content
    let titleSuffix: TitleSuffix
    let action: (() -> Void)?

    @State private var isHovered = false
    @State private var isPressed = false

    public init(
        title: String,
        description: String? = nil,
        icon: String? = nil,
        leadingColor: Color? = nil,
        titleColor: Color? = nil,
        @ViewBuilder titleSuffix: () -> TitleSuffix = { EmptyView() },
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.leadingColor = leadingColor
        self.titleColor = titleColor
        self.titleSuffix = titleSuffix()
        self.action = action
        self.content = content()
    }

    public var body: some View {
        #if os(iOS) || os(visionOS)
        iosBody
        #else
        macBody
        #endif
    }

    // MARK: - macOS

    private var macBody: some View {
        Group {
            if let action {
                Button(action: action) {
                    macRowContent
                }
                .buttonStyle(.plain)
            } else {
                macRowContent
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background {
            #if os(macOS) || os(visionOS)
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isPressed ? Color.primary.opacity(0.1) :
                        isHovered ? Color.primary.opacity(0.05) : Color.clear
                )
                .animation(.easeOut(duration: 0.15), value: isHovered)
                .animation(.easeOut(duration: 0.1), value: isPressed)
            #endif
        }
        #if os(macOS) || os(visionOS)
        .onHover { hovering in
            isHovered = hovering
        }
        .pressAction { pressed in
            isPressed = pressed
        }
        #endif
    }

    private var macRowContent: some View {
        HStack(alignment: .center, spacing: 16) {
            macLeadingAccessory

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(titleColor ?? Color.primary)

                    titleSuffix
                }

                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            content
        }
        .contentShape(Rectangle())
    }

    // MARK: - iOS

    private var iosBody: some View {
        Group {
            if let action {
                Button(action: action) {
                    iosRowContent
                }
                .buttonStyle(.plain)
            } else {
                iosRowContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .overlay(alignment: .top) {
            // 行顶部的发丝分隔线，起点与文字对齐（有无图标时分别对齐）。
            Rectangle()
                .fill(Color.lumiSeparator)
                .frame(height: 0.5)
                .padding(.leading, iosSeparatorInset)
        }
        .contentShape(Rectangle())
    }

    private var iosRowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            iosLeadingAccessory

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(titleColor ?? Color.lumiPrimaryLabel)

                    titleSuffix
                }

                if let description {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(Color.lumiSecondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(minWidth: 0, alignment: .leading)

            Spacer(minLength: 8)

            content
        }
        .frame(minWidth: 0, alignment: .leading)
    }

    /// 行首的图标或色块。
    @ViewBuilder
    private var macLeadingAccessory: some View {
        if let leadingColor {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(leadingColor)
                .frame(width: 24, height: 24)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
        } else if let icon {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
        }
    }

    /// 行首的图标或色块。
    @ViewBuilder
    private var iosLeadingAccessory: some View {
        if let leadingColor {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(leadingColor)
                .frame(width: 22, height: 22)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
        } else if let icon {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(Color.lumiSecondaryLabel)
                .frame(width: 22)
        }
    }

    /// 分隔线左侧缩进：无图标时与卡片内容边缘对齐，有图标时与文字对齐。
    private var iosSeparatorInset: CGFloat {
        (icon == nil && leadingColor == nil) ? 16 : 50
    }
}

/// 分组卡片内的开关行。
///
/// iOS 上使用全尺寸系统开关并补齐无障碍标签；macOS 保持桌面行内的小尺寸开关。
public struct AppSettingToggleRow: View {
    let title: String
    let description: String?
    let icon: String?
    @Binding var isOn: Bool

    public init(
        _ title: String,
        description: String? = nil,
        icon: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self._isOn = isOn
    }

    public var body: some View {
        #if os(iOS) || os(visionOS)
        AppSettingRow(title: title, description: description, icon: icon) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel(Text(title))
        }
        #else
        AppSettingRow(title: title, description: description, icon: icon) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        #endif
    }
}

// MARK: - Press Action

extension View {
    fileprivate func pressAction(onPress: @escaping (Bool) -> Void) -> some View {
        modifier(AppPressActionModifier(onPress: onPress))
    }
}

fileprivate struct AppPressActionModifier: ViewModifier {
    let onPress: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { _ in onPress(true) }
                    .onEnded { _ in onPress(false) }
            )
    }
}
