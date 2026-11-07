import SwiftUI

// MARK: - Value Row

/// 设置行：左侧标签，右侧灰色当前值。
///
/// 对应 iOS 设置里「标签 … 当前值」的标准表达（例如「主题  晨曦」）。
public struct AppSettingValueRow: View {
    let title: String
    let description: String?
    let value: String
    let icon: String?

    public init(
        _ title: String,
        value: String,
        description: String? = nil,
        icon: String? = nil
    ) {
        self.title = title
        self.value = value
        self.description = description
        self.icon = icon
    }

    public var body: some View {
        AppSettingRow(title: title, description: description, icon: icon) {
            Text(value)
                .font(.body)
                .foregroundStyle(Color.lumiSecondaryLabel)
                .lineLimit(1)
        }
    }
}

// MARK: - Disclosure Row

/// 设置行：整行可点，右侧显示当前值与箭头，用于「进入下一级页面」。
///
/// iOS 上单选与多步配置一律走「推送到独立页面」，而不是在行内展开控件。
public struct AppSettingDisclosureRow: View {
    let title: String
    let description: String?
    let value: String?
    let icon: String?
    let action: () -> Void

    public init(
        _ title: String,
        value: String? = nil,
        description: String? = nil,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.value = value
        self.description = description
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        AppSettingRow(title: title, description: description, icon: icon, action: action) {
            HStack(spacing: 6) {
                if let value {
                    Text(value)
                        .font(.body)
                        .foregroundStyle(Color.lumiSecondaryLabel)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.lumiTertiaryLabel)
            }
        }
    }
}

// MARK: - Action Row

/// 设置行：整行可点并执行动作，可标记为破坏性操作。
public struct AppSettingActionRow: View {
    let title: String
    let description: String?
    let icon: String?
    let isDestructive: Bool
    let action: () -> Void

    public init(
        _ title: String,
        description: String? = nil,
        icon: String? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }

    public var body: some View {
        AppSettingRow(
            title: title,
            description: description,
            icon: icon,
            titleColor: isDestructive ? Color.red : nil,
            action: action
        ) {
            EmptyView()
        }
    }
}

// MARK: - Checkmark Row

/// 单选列表行：左侧可选色块或图标，中间标题与副标题，右侧对勾标记当前选中项。
///
/// 用于 iOS 的「推送到独立页面 + 对勾标注当前值」范式。
public struct AppSettingCheckmarkRow: View {
    let title: String
    let description: String?
    let isSelected: Bool
    let leadingColor: Color?
    let leadingSystemImage: String?
    let action: () -> Void

    public init(
        _ title: String,
        description: String? = nil,
        isSelected: Bool = false,
        leadingColor: Color? = nil,
        leadingSystemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.isSelected = isSelected
        self.leadingColor = leadingColor
        self.leadingSystemImage = leadingSystemImage
        self.action = action
    }

    public var body: some View {
        AppSettingRow(
            title: title,
            description: description,
            icon: leadingSystemImage,
            leadingColor: leadingSystemImage == nil ? leadingColor : nil,
            action: action
        ) {
            // 始终保留对勾槽位，保证同一列表内各行的尾部内容对齐。
            Group {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Color.clear
                }
            }
            .frame(width: 18, height: 18)
        }
    }
}

// MARK: - Group Footer

/// 分组下方的说明文字（iOS 分组页脚）。
///
/// 当分组内容由 `AppSettingSection` 渲染时，优先使用 `AppSettingSection` 的 `footer` 参数；
/// 该组件用于分组之外的补充说明。
public struct AppSettingGroupFooter: View {
    let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.lumiSecondaryLabel)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 7)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var enabled = true

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                AppSettingSection(title: "Appearance", footer: "Themes only affect this app's appearance.") {
                    AppSettingValueRow("Theme", value: "Dawn")
                    AppSettingDisclosureRow("Appearance Mode", value: "Follow System") {}
                }

                AppSettingSection(title: "General") {
                    AppSettingToggleRow("Enable haptics", isOn: $enabled)
                    AppSettingActionRow("Clear Cache", isDestructive: true) {}
                }

                AppSettingSection(title: "Themes") {
                    AppSettingCheckmarkRow("Dawn", description: "Warm light theme", isSelected: true, leadingColor: .orange) {}
                    AppSettingCheckmarkRow("Deep Sea", description: "Low blue light", leadingColor: .blue) {}
                }
            }
            .padding()
            .frame(width: 380)
        }
    }

    return PreviewWrapper()
}
