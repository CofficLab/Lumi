import SwiftUI

/// Canvas 上叠加的错误浮层：标题 + 错误描述。
struct HotPreviewErrorOverlayView: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    let title: String
    let message: String
    var isOverlayingStaleFrame: Bool = false

    @State private var didCopy = false

    private let messageScrollMaxHeight: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(primaryTextColor)
            }

            ScrollView {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: messageScrollMaxHeight)

            HStack {
                Spacer(minLength: 0)
                copyButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 420)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var copyButton: some View {
        Button {
            let text = "[\(title)]\n\(message)"
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            withAnimation(.easeInOut(duration: 0.15)) { didCopy = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut(duration: 0.15)) { didCopy = false }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 8, weight: .medium))
                Text(didCopy
                    ? String(localized: "Copied", table: "EditorPreview")
                    : String(localized: "Copy", table: "EditorPreview"))
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(didCopy ? .green : tertiaryTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }

    private var primaryTextColor: Color {
        isOverlayingStaleFrame ? .white.opacity(0.9) : themeVM.activeAppTheme.workspaceTextColor()
    }

    private var secondaryTextColor: Color {
        isOverlayingStaleFrame
            ? .white.opacity(0.7)
            : themeVM.activeAppTheme.workspaceSecondaryTextColor()
    }

    private var tertiaryTextColor: Color {
        isOverlayingStaleFrame
            ? .white.opacity(0.45)
            : themeVM.activeAppTheme.workspaceTertiaryTextColor()
    }

    private var background: some View {
        Group {
            if isOverlayingStaleFrame {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeVM.activeAppTheme.workspaceBackgroundColor())
            }
        }
    }

    private var borderColor: Color {
        isOverlayingStaleFrame ? .orange : themeVM.activeAppTheme.workspaceTertiaryTextColor()
    }
}
