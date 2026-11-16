import SwiftUI

/// Rail 侧边栏：服务器列表 + 添加入口。
struct ServerSidebarView: View {
    @ObservedObject var viewModel: ServerManagerViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.servers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(ServerManagerLocalization.string("No servers yet. Add one to get started."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxHeight: .infinity)
            } else {
                List(selection: $viewModel.selectedID) {
                    ForEach(viewModel.servers) { server in
                        ServerRow(
                            server: server,
                            state: viewModel.probeState(for: server.id)
                        )
                        .tag(server.id)
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()
            Button {
                viewModel.isAddSheetPresented = true
            } label: {
                Label(ServerManagerLocalization.string("Add Server"), systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
        .sheet(isPresented: $viewModel.isAddSheetPresented) {
            AddServerSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.refresh()
        }
    }
}

private struct ServerRow: View {
    let server: ServerConfig
    let state: ServerManagerViewModel.ProbeState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.body)
                Text(server.destination)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
            Spacer()
            if case .probing = state {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .padding(.vertical, 2)
    }

    private var dotColor: Color {
        switch state {
        case .online: return .green
        case .failed: return .red
        case .probing: return .orange
        case .idle: return .secondary
        }
    }
}