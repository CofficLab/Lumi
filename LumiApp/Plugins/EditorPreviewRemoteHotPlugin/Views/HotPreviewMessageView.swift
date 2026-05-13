import SwiftUI

struct HotPreviewMessageView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    let systemImage: String
    let message: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .light))
                .foregroundColor(color)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
        }
    }
}
