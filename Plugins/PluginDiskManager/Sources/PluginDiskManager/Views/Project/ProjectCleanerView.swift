import SwiftUI
import DiskManagerKit

struct ProjectCleanerView: View {
    @StateObject private var viewModel = ProjectCleanerViewModel()
    @State private var showCleanConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            // 扫描控制区域
            if viewModel.projects.isEmpty == false && viewModel.isScanning == false {
                ProjectScanControlBar(viewModel: viewModel)
            }

            VStack {
                // 扫描进度
                if viewModel.isScanning {
                    ProjectScanProgressView(viewModel: viewModel)
                }

                // 内容列表
                if viewModel.projects.isEmpty && !viewModel.isScanning {
                    EmptyProjectView(viewModel: viewModel)
                } else if !viewModel.isScanning {
                    List {
                        ForEach(viewModel.projects) { project in
                            Section(header: ProjectSectionHeader(project: project)) {
                                ForEach(project.cleanableItems) { item in
                                    ProjectItemRow(item: item, viewModel: viewModel)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(maxHeight: .infinity)

            // 底部操作栏
            if !viewModel.isScanning {
                ProjectCleanerFooter(viewModel: viewModel)
            }
        }
        .onAppear {
            Task { await viewModel.scanProjectsIfNeeded() }
        }
        .alert(Text(PluginDiskManagerLocalization.string("Confirm Cleanup")), isPresented: $showCleanConfirmation) {
            Button(role: .cancel) { } label: {
                Text(PluginDiskManagerLocalization.string("Cancel"))
            }
            Button(role: .destructive) {
                viewModel.cleanSelected()
            } label: {
                Text(PluginDiskManagerLocalization.string("Clean"))
            }
        } message: {
            Text(PluginDiskManagerLocalization.string("Are you sure you want to delete the selected build artifacts (node_modules, target, etc)? This will free up space but require rebuilding projects."))
        }
    }
}
