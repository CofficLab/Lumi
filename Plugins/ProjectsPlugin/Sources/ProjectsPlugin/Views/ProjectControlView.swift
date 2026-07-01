import LumiCoreKit
import LumiUI
import SwiftUI

struct ProjectControlView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let projectPathStore: LumiCurrentProjectPathStoring?
    @ObservedObject private var store: ProjectsStore
    @State private var isPopoverPresented = false

    init(projectPathStore: LumiCurrentProjectPathStoring? = nil, store: ProjectsStore) {
        self.projectPathStore = projectPathStore
        self.store = store
    }

    var body: some View {
        Button {
            isPopoverPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .semibold))

                Text(store.currentProject?.name ?? "Projects")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ProjectsPopoverView(store: store)
        }
    }
}
