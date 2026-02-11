import SwiftUI

// MARK: - 玻璃列表行
///
/// 玻璃态列表行，用于列表项。
///
struct GlassRow<Content: View>: View {
    let content: Content
    @State private var isHovering = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignTokens.Spacing.md)
            .background(rowBackground)
            .overlay(rowBorder)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeOut(duration: DesignTokens.Duration.micro)) {
                    isHovering = hovering
                }
            }
    }

    private var rowBackground: some View {
        Group {
            if isHovering {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(DesignTokens.Material.glass.opacity(0.2))
            } else {
                SwiftUI.Color.clear
            }
        }
    }

    @ViewBuilder private var rowBorder: some View {
        if isHovering {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .stroke(
                    SwiftUI.Color.white.opacity(0.08),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - 预览
#Preview("玻璃列表行") {
    VStack(spacing: DesignTokens.Spacing.sm) {
        GlassRow {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(DesignTokens.Color.semantic.primary)
                Text("列表项 1")
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Spacer()
            }
        }

        GlassRow {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(DesignTokens.Color.semantic.warning)
                Text("列表项 2")
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Spacer()
            }
        }

        GlassRow {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                Text("列表项 3")
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Spacer()
            }
        }
    }
    .padding(DesignTokens.Spacing.lg)
    .frame(width: 300)
    .background(DesignTokens.Color.basePalette.deepBackground)
}
