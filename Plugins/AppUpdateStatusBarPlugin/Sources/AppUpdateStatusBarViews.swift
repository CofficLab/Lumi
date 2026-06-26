import LumiUI
import SwiftUI

struct AppUpdateStatusBarContentView: View {
    @ObservedObject var store: AppUpdateStatusBarStore

    var body: some View {
        if store.hasPendingUpdate {
            HStack(spacing: 3) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.appMicroEmphasized)
                Text(PluginAppUpdateStatusBarLocalization.string("Update"))
                    .font(.appMicroEmphasized)
            }
            .foregroundStyle(.black)
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
                        Text(PluginAppUpdateStatusBarLocalization.string("New version is ready"))
                            .font(.appCallout)
                            .foregroundColor(theme.textPrimary)

                        Text(String(format: PluginAppUpdateStatusBarLocalization.string("Lumi %@ downloaded"), version))
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)
                    }

                    Spacer(minLength: 8)

                    Button(action: store.installPreparedUpdate) {
                        Text(PluginAppUpdateStatusBarLocalization.string("Restart to Update"))
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
