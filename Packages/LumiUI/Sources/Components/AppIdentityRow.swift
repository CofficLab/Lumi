import SwiftUI

public struct AppIdentityRow: View {
    @LumiTheme private var theme

    let title: String
    let metadata: [String]
    let titleColor: Color?
    let metadataColor: Color?

    public init(
        title: String,
        metadata: [String] = [],
        titleColor: Color? = nil,
        metadataColor: Color? = nil
    ) {
        self.title = title
        // 等价于 filter { !trimmingCharacters().isEmpty },但不为每个条目
        // 构造 trimmed 新串:init 在每次宿主 body 求值时执行(消息行 header),
        // 正常条目首个字符即非空白,allSatisfy 在首字符处短路。
        self.metadata = metadata.filter { item in
            !item.isEmpty && !item.allSatisfy { $0.isWhitespace || $0.isNewline }
        }
        self.titleColor = titleColor
        self.metadataColor = metadataColor
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(DesignTokens.Typography.caption1)
                .fontWeight(.medium)
                .foregroundColor(titleColor ?? theme.textPrimary)
                .lineLimit(1)

            ForEach(Array(metadata.enumerated()), id: \.offset) { _, item in
                Text("·")
                    .foregroundColor(metadataColor ?? theme.textSecondary)
                Text(item)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(metadataColor ?? theme.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AppIdentityRow(
            title: "GPT-4",
            metadata: ["OpenAI", "2024"]
        )
        AppIdentityRow(
            title: "Claude",
            metadata: ["Anthropic"],
            titleColor: .purple
        )
        AppIdentityRow(
            title: "Standalone"
        )
    }
    .padding()
    .frame(width: 300)
    .background(Color.gray.opacity(0.15))
}
