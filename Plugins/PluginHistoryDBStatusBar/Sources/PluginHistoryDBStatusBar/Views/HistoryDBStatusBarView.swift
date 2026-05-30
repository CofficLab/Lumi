import SwiftUI
import LumiUI
import LumiCoreKit

public struct HistoryDBStatusBarView: View {
    private let historyService: (any HistoryQueryService)?

    public init(historyService: (any HistoryQueryService)?) {
        self.historyService = historyService
    }

    public var body: some View {
        StatusBarHoverContainer(
            detailView: HistoryDBDetailView(historyService: historyService),
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
