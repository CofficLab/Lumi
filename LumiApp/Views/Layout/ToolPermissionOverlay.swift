import SwiftUI

struct ToolPermissionOverlay: View {
    @EnvironmentObject private var permissionRequestVM: WindowPermissionRequestVM
    @EnvironmentObject private var permissionHandlingVM: WindowPermissionHandlingVM

    @State private var isResponding = false

    var body: some View {
        Group {
            if let request = permissionRequestVM.pendingPermissionRequest {
                overlay(for: request)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1_000)
            }
        }
        .animation(.easeOut(duration: 0.16), value: permissionRequestVM.pendingPermissionRequest?.id)
    }

    private func overlay(for request: PermissionRequest) -> some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                header(for: request)

                VStack(alignment: .leading, spacing: 8) {
                    Text(request.summary)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let reason = request.riskLevel.reason {
                        Label(reason, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }

                detailsView(request.details)

                HStack(spacing: 10) {
                    Spacer()

                    Button {
                        respond(false)
                    } label: {
                        Text(String(localized: "Deny"))
                            .frame(minWidth: 84)
                    }
                    .keyboardShortcut(.cancelAction)

                    Button {
                        respond(true)
                    } label: {
                        Text(String(localized: "Allow"))
                            .frame(minWidth: 84)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .disabled(isResponding)
            }
            .padding(20)
            .frame(width: 520)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 12)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.14))
            }
        }
    }

    private func header(for request: PermissionRequest) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 32, height: 32)
                .background(.orange.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Tool permission required"))
                    .font(.title3.weight(.semibold))
                Text(request.riskLevel.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func detailsView(_ details: String) -> some View {
        ScrollView {
            Text(details)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(maxHeight: 140)
        .background(Color.black.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func respond(_ allowed: Bool) {
        guard !isResponding else { return }
        isResponding = true
        Task {
            await permissionHandlingVM.respondToPermissionRequest(allowed: allowed)
            isResponding = false
        }
    }
}

#Preview("Tool Permission Overlay") {
    Text("Content")
        .frame(width: 700, height: 440)
        .overlay {
            ToolPermissionOverlay()
        }
        .inRootView()
}
