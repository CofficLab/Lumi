import SwiftUI

/// 轻量标签组件：用于展示状态/分类等短文本信息。
struct AppTag: View {
    enum Style {
        case subtle
        case accent
    }

    let title: String
    let systemImage: String?
    let style: Style

    init(
        _ title: String,
        systemImage: String? = nil,
        style: Style = .subtle
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
    }

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .medium))
            }
            Text(title)
                .font(DesignTokens.Typography.caption2)
                .lineLimit(1)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var foregroundColor: Color {
        switch style {
        case .subtle:
            return DesignTokens.Color.semantic.textSecondary
        case .accent:
            return DesignTokens.Color.semantic.textPrimary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .subtle:
            return DesignTokens.Color.semantic.textSecondary.opacity(0.10)
        case .accent:
            return Color.accentColor.opacity(0.14)
        }
    }

    private var borderColor: Color {
        switch style {
        case .subtle:
            return Color.white.opacity(0.06)
        case .accent:
            return Color.accentColor.opacity(0.25)
        }
    }
}

#Preview {
    HStack(spacing: 10) {
        AppTag("Qwen 3")
        AppTag("Vision", systemImage: "eye", style: .accent)
    }
    .padding()
    .inRootView()
}
