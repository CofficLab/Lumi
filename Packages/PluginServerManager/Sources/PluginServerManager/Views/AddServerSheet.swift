import SwiftUI

/// 添加服务器表单。只收集连接参数，不收集密码。
struct AddServerSheet: View {
    @ObservedObject var viewModel: ServerManagerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var user = "root"
    @State private var group = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(ServerManagerLocalization.string("Add Server"))
                .font(.headline)

            Form {
                TextField(ServerManagerLocalization.string("Name"), text: $name)
                TextField(ServerManagerLocalization.string("Host"), text: $host, prompt: Text("IP / ~/.ssh/config alias"))
                TextField(ServerManagerLocalization.string("Port"), text: $port)
                TextField(ServerManagerLocalization.string("User"), text: $user)
                TextField(ServerManagerLocalization.string("Group"), text: $group)
            }
            .formStyle(.grouped)

            Text(ServerManagerLocalization.string("Authentication uses your existing ~/.ssh keys and ssh-agent. No passwords are stored."))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(ServerManagerLocalization.string("Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(ServerManagerLocalization.string("Save")) {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving || host.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func save() {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        guard !trimmedHost.isEmpty else { return }
        let parsedPort = Int(port.trimmingCharacters(in: .whitespaces)) ?? 22
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await viewModel.addServer(
                    name: name.trimmingCharacters(in: .whitespaces),
                    host: trimmedHost,
                    port: parsedPort,
                    user: user.trimmingCharacters(in: .whitespaces).isEmpty ? "root" : user.trimmingCharacters(in: .whitespaces),
                    group: group.trimmingCharacters(in: .whitespaces)
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}