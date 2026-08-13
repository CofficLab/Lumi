import KernelLumi
import LumiUI
import SwiftUI

public struct ProjectFilesHeaderView: View {
    let kernel: KernelLumi

    @EnvironmentObject private var themeVM: AppThemeVM
    @StateObject private var projectObserver: ProjectFilesProjectObserver

    public init(kernel: KernelLumi) {
        self.kernel = kernel
        _projectObserver = StateObject(
            wrappedValue: ProjectFilesProjectObserver(project: kernel.project)
        )
    }

    private var project: (any ProjectProviding)? {
        projectObserver.project ?? kernel.project
    }

    private var visibleFileURLs: [URL] {
        ProjectFilesState.visibleFileURLs(
            openFileURLs: project?.openFileURLs ?? [],
            currentFileURL: project?.currentFileURL
        )
    }

    private var currentFileURL: URL? {
        project?.currentFileURL?.standardizedFileURL
    }

    public var body: some View {
        AppToolbarContainer(
            height: 40,
            backgroundStyle: .panel,
            padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        ) {
            if let project = project, !visibleFileURLs.isEmpty {
                filesScrollView(project: project)
            } else {
                emptyState
            }
        }
        .borderBottom()
    }

    private var emptyState: some View {
        HStack {
            Text(project == nil ? "No project open" : "No files open")
                .font(.appMicro)
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
            Spacer()
        }
    }

    private func filesScrollView(project: any ProjectProviding) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleFileURLs, id: \.self) { fileURL in
                    ProjectFileItemView(
                        fileURL: fileURL,
                        isCurrent: currentFileURL == fileURL.standardizedFileURL,
                        theme: themeVM.activeChromeTheme,
                        onSelect: {
                            project.updateCurrentFile(fileURL)
                        },
                        onClose: {
                            project.closeFile(fileURL)
                        },
                        onCloseOthers: {
                            for otherURL in visibleFileURLs where otherURL != fileURL {
                                project.closeFile(otherURL)
                            }
                        }
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }
}
