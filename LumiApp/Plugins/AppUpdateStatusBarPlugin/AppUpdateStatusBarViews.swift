import SwiftUI
import LumiUI

struct AppUpdateStatusBarContentView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var store: AppUpdateStatusBarStore

    var body: some View {
        if store.hasPendingUpdate {
            HStack(spacing: 3) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.appMicroEmphasized)
                Text(String(localized: "Update", table: "AppUpdateStatusBar"))
                    .font(.appMicroEmphasized)
            }
            .foregroundColor(theme.info)
            .padding(.horizontal, 5)
            .frame(height: 16)
            .appSurface(style: .custom(theme.info.opacity(0.14)), cornerRadius: 4)
        }
    }
}

struct AppUpdateStatusBarPopupView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var store: AppUpdateStatusBarStore

    var body: some View {
        if let version = store.pendingVersion {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.info)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "New version is ready", table: "AppUpdateStatusBar"))
                            .font(.appCallout)
                            .foregroundColor(theme.textPrimary)

                        Text(String(format: String(localized: "Lumi %@ downloaded", table: "AppUpdateStatusBar"), version))
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)
                    }

                    Spacer(minLength: 8)

                    Button(action: store.installPreparedUpdate) {
                        Text(String(localized: "Restart to Update", table: "AppUpdateStatusBar"))
                            .font(.appCaptionEmphasized)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .appSurface(style: .custom(theme.info), cornerRadius: 5)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }
}

#Preview("App Update Status Bar") {
    VStack(spacing: 12) {
        AppUpdateStatusBarContentView(store: .shared)
        AppUpdateStatusBarPopupView(store: .shared)
            .frame(width: 300)
    }
    .padding()
}
