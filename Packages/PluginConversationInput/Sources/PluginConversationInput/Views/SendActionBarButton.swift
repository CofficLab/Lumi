import LumiUI
import ProviderConversationInput
import ProviderMessageSender
import SwiftUI

/// Action Bar 上的发送/停止按钮
///
/// 视图负责 nil 检查与错误展示；正常情况下将非 nil 的依赖交给 ViewModel 管理状态和逻辑。
struct SendActionBarButton: View {
    let viewModel: SendActionBarViewModel?
    let missingProviders: [String]

    @State private var showErrorPopover = false

    var body: some View {
        HStack(spacing: 6) {
            if let viewModel {
                normalContent(viewModel: viewModel)
            } else {
                ErrorButton {
                    showErrorPopover = true
                }
                .popover(isPresented: $showErrorPopover) {
                    errorPopoverContent
                }
            }
        }
    }

    // MARK: - Normal content

    @ViewBuilder
    private func normalContent(viewModel: SendActionBarViewModel) -> some View {
        let state = viewModel.state

        if state.showsSendButton {
            SendButton(canSend: state.canSend, action: { viewModel.send() })
                .help(LumiPluginLocalization.string("Send", bundle: .module))
        }

        if state.showsStopButton {
            StopButton(action: { viewModel.cancel() })
                .help(LumiPluginLocalization.string("Stop", bundle: .module))
        }
    }

    // MARK: - Popover

    private var errorPopoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Provider Error")
                    .font(.headline)
            }
            Text("Missing provider(s): \(missingProviders.joined(separator: ", "))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(minWidth: 200)
    }
}

// MARK: - ErrorButton

private struct ErrorButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 16))
        }
        .buttonStyle(.plain)
        .help("Provider configuration error — click for details")
    }
}
