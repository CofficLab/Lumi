import SwiftUI
import LumiUI

struct DragPreview: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let fileURL: URL

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.appMicroEmphasized)
                .foregroundColor(theme.textSecondary)
            Text(fileURL.lastPathComponent)
                .font(.appMicroEmphasized)
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .appSurface(style: .custom(theme.elevatedSurface.opacity(0.95)), cornerRadius: 8)
    }
}
