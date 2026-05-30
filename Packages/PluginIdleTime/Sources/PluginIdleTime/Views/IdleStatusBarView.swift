import SwiftUI
import LumiCoreKit
import LumiUI

public struct IdleStatusBarView: View {
    @StateObject private var idleTimeVM = AppIdleTimeVM()
    @EnvironmentObject private var projectVM: WindowProjectVM

    public var body: some View {
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
