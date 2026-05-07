import SwiftUI

/// 通用图标按钮：统一消息区等场景的小型操作按钮样式。
struct AppIconButton: View {
    enum Size {
        case compact
        case regular
    }

    let systemImage: String
    let label: String?
    let tint: Color
    let size: Size
    let isActive: Bool
    let action: () -> Void

    init(
        systemImage: String,
        label: String? = nil,
        tint: Color = DesignTokens.Color.semantic.textSecondary.opacity(0.8),
        size: Size = .compact,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = label
        self.tint = tint
        self.size = size
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(iconFont)
                if let label {
                    Text(label)
                        .font(labelFont)
                }
            }
            .foregroundStyle(tint)
            .padding(contentPadding)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isActive {
            return DesignTokens.Color.semantic.textSecondary.opacity(0.16)
        }
        return DesignTokens.Color.semantic.textSecondary.opacity(0.08)
    }

    private var borderColor: Color {
        if isActive {
            return DesignTokens.Color.semantic.textSecondary.opacity(0.22)
        }
        return .clear
    }

    private var iconFont: Font {
        switch size {
        case .compact: .system(size: 10, weight: .medium)
        case .regular: .system(size: 11, weight: .semibold)
        }
    }

    private var labelFont: Font {
        switch size {
        case .compact: .system(size: 11, weight: .medium)
        case .regular: .system(size: 12, weight: .semibold)
        }
    }

    private var contentPadding: CGFloat {
        switch size {
        case .compact: 6
        case .regular: 8
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        AppIconButton(systemImage: "chevron.up", label: "折叠") {}
        AppIconButton(systemImage: "curlybraces") {}
    }
    .padding()
    .inRootView()
}
