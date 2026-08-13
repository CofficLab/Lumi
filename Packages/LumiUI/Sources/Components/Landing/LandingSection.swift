import SwiftUI

/// 落地页的统一分区容器。
///
/// 由可选图标 + 标题(+ 副标题)的 `GlassSectionHeader` 头部、以及紧随其后的
/// 自定义内容组成,区块之间保持一致的垂直节奏。
public struct LandingSection<Content: View>: View {
    private let icon: String?
    private let title: String
    private let subtitle: String?
    private let spacing: CGFloat
    @ViewBuilder private let content: Content

    /// 创建分区。
    public init(
        title: String,
        icon: String? = nil,
        subtitle: String? = nil,
        spacing: CGFloat = 14,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            header
            content
        }
    }

    @ViewBuilder
    private var header: some View {
        if let icon {
            GlassSectionHeader(icon: icon, title: title, subtitle: subtitle)
        } else {
            GlassSectionHeader(title: title, subtitle: subtitle)
        }
    }
}
