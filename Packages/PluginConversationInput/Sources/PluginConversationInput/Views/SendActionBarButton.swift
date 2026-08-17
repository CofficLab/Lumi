import LumiUI
import ProviderConversationInput
import ProviderMessageSender
import SwiftUI

/// Action Bar 上的发送/停止按钮
///
/// 视图本身只负责布局和交互；所有状态管理与发送逻辑由 `SendActionBarViewModel` 承载。
/// 当 `input` 或 `sender` 任一为 nil 时，显示错误按钮并可通过 popover 查看原因。
struct SendActionBarButton: View {
    @State private var viewModel: SendActionBarViewModel
    @State private var showErrorPopover = false

    init(input: (any ConversationInputProviding)?, sender: (any MessageSendingProviding)?) {
        _viewModel = State(wrappedValue: SendActionBarViewModel(input: input, sender: sender))
    }

    var body: some View {
        HStack(spacing: 6) {
            if viewModel.hasError {
                ErrorButton {
                    showErrorPopover = true
                }
                .popover(isPresented: $showErrorPopover) {
                    errorPopoverContent
                }
            } else {
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
        }
        .onAppear { viewModel.setup() }
        .onDisappear { viewModel.teardown() }
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
            if let message = viewModel.initializationError {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
