import SwiftUI
import LumiUI

public struct HistoryDBStatusBarView: View {
    public var body: some View {
        StatusBarHoverContainer(
            detailView: HistoryDBDetailView(),
            popoverWidth: 980,
            id: "history-db-status"
        ) {
            Image(systemName: "tablecells")
                .font(.appMicroEmphasized)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
    }
}
