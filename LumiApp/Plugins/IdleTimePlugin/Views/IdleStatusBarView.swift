import SwiftUI
import LumiUI

struct IdleStatusBarView: View {
    @EnvironmentObject private var idleTimeVM: AppIdleTimeVM
    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
        Group {
            if !projectVM.currentProjectPath.isEmpty {
                StatusBarHoverContainer(
                    detailView: IdlePopoverView(snapshot: idleTimeVM.snapshot),
                    popoverWidth: 480,
                    id: "idle-time-status"
                ) {
                    Image(systemName: "moon.zzz")
                        .font(.appMicroEmphasized)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
            }
        }
    }

}
