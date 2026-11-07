import SwiftUI

/// 说明书文档头:产品名称 + 手册字样 + 顶部粗分隔线。
///
/// 模拟纸质说明书的封面标题,克制、无装饰、无动效。
public struct ManualHeader: View {
    @LumiTheme private var theme

    private let title: String
    private let subtitle: String

    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.textPrimary)

            Text(subtitle)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)

            Rectangle()
                .fill(theme.textPrimary.opacity(0.7))
                .frame(height: 1.5)
                .padding(.top, 4)
        }
    }
}

#Preview {
    ManualHeader(title: "应用图标设计器", subtitle: "使用手册")
        .padding(20)
        .frame(width: 420)
}
