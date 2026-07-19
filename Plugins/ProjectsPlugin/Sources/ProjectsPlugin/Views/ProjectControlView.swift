import LumiUI
import SwiftUI

struct ProjectControlView: View {
    @LumiTheme private var theme: any LumiUITheme
    @ObservedObject private var viewModel: ProjectsViewModel
    @State private var isPopoverPresented = false

    init(viewModel: ProjectsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Button {
            isPopoverPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .semibold))

                Text(viewModel.currentProject?.name ?? "Projects")
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
            ProjectsPopoverView(viewModel: viewModel)
        }
    }
}
