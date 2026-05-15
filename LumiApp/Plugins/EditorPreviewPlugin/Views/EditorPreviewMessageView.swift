import SwiftUI

struct HotPreviewMessageView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    let systemImage: String
    let message: String
    let color: Color

    /// Whether to show a copy button. Defaults to `true` when the color indicates an error/warning.
    var showCopyButton: Bool?

    @State private var didCopy = false

    private var shouldShowCopyButton: Bool {
        showCopyButton ?? (color == .orange || color == .red)
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .light))
                .foregroundColor(color)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .multilineTextAlignment(.center)
            if shouldShowCopyButton {
                copyButton
            }
        }
    }

    private var copyButton: some View {
        Button {
            copyMessage()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                Text(didCopy
                    ? String(localized: "Copied", table: "EditorPreview")
                    : String(localized: "Copy Error", table: "EditorPreview"))
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(
                didCopy
                    ? .green
                    : themeVM.activeAppTheme.workspaceSecondaryTextColor().opacity(0.8)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func copyMessage() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message, forType: .string)
        withAnimation(.easeInOut(duration: 0.2)) {
            didCopy = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                didCopy = false
            }
        }
    }
}
