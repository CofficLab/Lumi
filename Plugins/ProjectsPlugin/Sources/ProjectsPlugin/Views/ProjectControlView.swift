import LumiCoreKit
import LumiUI
import SwiftUI

struct ProjectControlView: View {
    let projectPathStore: LumiCurrentProjectPathStoring?
    @ObservedObject private var store: ProjectsStore
    @State private var isPopoverPresented = false

    init(projectPathStore: LumiCurrentProjectPathStoring? = nil) {
        self.projectPathStore = projectPathStore
        self.store = ProjectsPlugin.sharedStore
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
                    .truncationMode(.middle)
                    .frame(maxWidth: 180)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .rotationEffect(.degrees(isPopoverPresented ? 180 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.primary.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ProjectsPopoverView(store: store)
        }
        .onAppear {
            syncProjectPath(store.currentProject?.path)
        }
        .onChange(of: store.currentProject?.path) { _, newPath in
            syncProjectPath(newPath)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiOpenExternalProject)) { notification in
            guard let path = notification.userInfo?[LumiOpenProjectUserInfoKey.path] as? String else {
                return
            }
            try? store.addProject(path: path, select: true)
        }
        .accessibilityLabel(LumiPluginLocalization.string("Projects", bundle: .module))
    }

    private func syncProjectPath(_ path: String?) {
        projectPathStore?.setCurrentProjectPath(path ?? "", reason: "ProjectControlView同步")
    }
}
