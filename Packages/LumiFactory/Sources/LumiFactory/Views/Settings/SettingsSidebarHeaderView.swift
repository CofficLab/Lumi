import LumiKernel
import LumiUI
import SwiftUI

struct SettingsSidebarHeaderView: View {
    let kernel: LumiKernel
    private let appInfo = AppBundleInfo()

    var body: some View {
        AppSettingsSidebarHeader(
            name: appInfo.name,
            version: appInfo.version,
            build: appInfo.build,
            topSpacing: 22,
            bottomSpacing: 8
        ) {
            HStack {
                Spacer()
                LogoView(scene: .about)
                    .frame(width: 64, height: 64)
                Spacer()
            }
        }
    }
}
