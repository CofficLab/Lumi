import LumiKernel
import LumiUI
import SwiftUI

public struct IdleStatusBarView: View {
    let projectPath: String
    @StateObject private var idleTimeVM = AppIdleTimeVM()

    public init(projectPath: String) {
        self.projectPath = projectPath
    }

    public var body: some View {
        Group {
            if !projectPath.isEmpty {
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
