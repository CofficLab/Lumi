import LumiKernel
import LumiUI
import SwiftUI

struct ProjectFileItemView: View {
    @LumiUI.LumiTheme private var uiTheme: any LumiUITheme
    @LumiMotionPreferenceReader private var motionPreference

    let fileURL: URL
    let isCurrent: Bool
    let theme: any LumiAppChromeTheme
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                if isCurrent {
                    Circle()
                        .fill(uiTheme.warning)
                        .frame(width: 6, height: 6)
                }

                Text(fileURL.lastPathComponent)
                    .font(isCurrent ? .appMicroEmphasized : .appMicro)
                    .foregroundColor(
                        isCurrent ? theme.workspaceTextColor() : theme.workspaceSecondaryTextColor()
                    )
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(height: 28)
            .appSurface(
                style: .custom(theme.workspaceTextColor().opacity(isCurrent ? 0.08 : 0.03)),
                cornerRadius: 7,
                borderColor: theme.workspaceTextColor().opacity(isCurrent ? 0.12 : 0.04)
            )
        }
        .buttonStyle(.plain)
        .animation(LumiMotion.enabled(LumiMotion.selection, preference: motionPreference), value: isCurrent)
    }
}
