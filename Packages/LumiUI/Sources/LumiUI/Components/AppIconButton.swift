import SwiftUI

public struct AppIconButton: View {
    @LumiTheme private var theme

    public enum Size {
        case compact
        case regular
    }

    let systemImage: String
    let label: String?
    let tint: Color?
    let size: Size
    let isActive: Bool
    let action: () -> Void

    public init(
        systemImage: String,
        label: String? = nil,
        tint: Color? = nil,
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

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(iconFont)
                if let label {
                    Text(label)
                        .font(labelFont)
                }
            }
            .foregroundStyle(tint ?? theme.textSecondary.opacity(0.8))
            .padding(resolvedContentPadding)
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
            theme.textSecondary.opacity(0.16)
        } else {
            theme.textSecondary.opacity(0.08)
        }
    }

    private var borderColor: Color {
        if isActive {
            theme.textSecondary.opacity(0.22)
        } else {
            .clear
        }
    }

    private var iconFont: Font {
        switch size {
        case .compact:
            .system(size: 10, weight: .medium)
        case .regular:
            .system(size: 11, weight: .semibold)
        }
    }

    private var labelFont: Font {
        switch size {
        case .compact:
            .system(size: 11, weight: .medium)
        case .regular:
            .system(size: 12, weight: .semibold)
        }
    }

    var resolvedContentPadding: CGFloat {
        switch size {
        case .compact:
            6
        case .regular:
            8
        }
    }
}
