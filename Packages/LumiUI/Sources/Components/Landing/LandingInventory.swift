import SwiftUI

/// 一条清单项数据,供 `LandingInventory` 渲染。
public struct LandingInventoryItem: Identifiable {
    public let id = UUID()
    public let icon: String
    public let title: String
    public let description: String?
    public let mono: Bool   // title 是否用等宽字体(适合命令/格式名)

    public init(icon: String, title: String, description: String? = nil, mono: Bool = false) {
        self.icon = icon
        self.title = title
        self.description = description
        self.mono = mono
    }
}

/// 单列清单:图标 + 名称(+说明),行间以分隔线区隔,收纳在一张低调卡片里。
///
/// 适合「支持的命令 / 支持的格式 / 可用动作」这类条目较多的能力清单——
/// 比 `LandingFeatureGrid` 更紧凑、信息密度更高。
public struct LandingInventory: View {
    @LumiTheme private var theme

    private let items: [LandingInventoryItem]
    private let tint: Color?

    private var accent: Color { tint ?? theme.primary }

    public init(items: [LandingInventoryItem], tint: Color? = nil) {
        self.items = items
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(item)
                if index < items.count - 1 {
                    AppDivider()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.textSecondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.appSubtleBorder, lineWidth: 1)
        )
    }

    private func row(_ item: LandingInventoryItem) -> some View {
        HStack(spacing: 11) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 22)

            Text(item.title)
                .font(item.mono ? .appMonoCaption : .appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)

            if let description = item.description {
                Text(description)
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    LandingInventory(items: [
        .init(icon: "arrow.down", title: "brew install", description: "安装软件包", mono: true),
        .init(icon: "magnifyingglass", title: "brew search", description: "搜索可用包", mono: true),
        .init(icon: "arrow.up", title: "brew upgrade", description: "批量升级", mono: true),
        .init(icon: "trash", title: "brew uninstall", description: "卸载软件包", mono: true)
    ])
    .padding()
    .frame(width: 420)
}
