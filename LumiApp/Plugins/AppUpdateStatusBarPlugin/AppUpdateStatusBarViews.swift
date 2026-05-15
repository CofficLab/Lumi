import SwiftUI
import LumiUI

struct AppUpdateStatusBarContentView: View {
    @ObservedObject var store: AppUpdateStatusBarStore

    var body: some View {
        if store.hasPendingUpdate {
            HStack(spacing: 3) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("更新")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(Color(hex: "0A84FF"))
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(Color(hex: "0A84FF").opacity(0.14))
            .cornerRadius(4)
        }
    }
}

struct AppUpdateStatusBarPopupView: View {
    @ObservedObject var store: AppUpdateStatusBarStore

    var body: some View {
        if let version = store.pendingVersion {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "0A84FF"))
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("新版本已准备好")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                        Text("Lumi \(version) 已下载完成")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "98989E"))
                    }

                    Spacer(minLength: 8)

                    Button(action: store.installPreparedUpdate) {
                        Text("重启更新")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(Color(hex: "0A84FF"))
                            .cornerRadius(5)
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
