import SwiftUI

/// 统一的身份信息行：标题 + 可选元信息（以分隔点连接）。
struct AppIdentityRow: View {
    let title: String
    let metadata: [String]
    let titleColor: Color
    let metadataColor: Color

    init(
        title: String,
        metadata: [String] = [],
        titleColor: Color = DesignTokens.Color.semantic.textPrimary,
        metadataColor: Color = DesignTokens.Color.semantic.textSecondary
    ) {
        self.title = title
        self.metadata = metadata.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.titleColor = titleColor
        self.metadataColor = metadataColor
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(DesignTokens.Typography.caption1)
                .fontWeight(.medium)
                .foregroundColor(titleColor)
                .lineLimit(1)

            ForEach(Array(metadata.enumerated()), id: \.offset) { _, item in
                Text("·")
                    .foregroundColor(metadataColor)
                Text(item)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(metadataColor)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        AppIdentityRow(title: "Lumi", metadata: ["openai", "gpt-5.4"])
        AppIdentityRow(title: "System", titleColor: DesignTokens.Color.semantic.textSecondary)
    }
    .padding()
    .inRootView()
}
