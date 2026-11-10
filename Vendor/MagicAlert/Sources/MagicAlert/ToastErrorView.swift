import SwiftUI

/// 错误详情Toast视图组件
/// 专门用于显示详细的错误信息，包括工具栏和错误内容
struct ToastErrorView: View {
    /// 要显示的错误对象
    let error: Error
    /// 错误标题
    let title: String
    /// 关闭回调函数
    let onDismiss: () -> Void
    /// 显示动画处理回调
    let onAppear: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 错误图标和标题 + 工具栏
            HStack {
                Image.warningIcon
                    .foregroundStyle(.red)
                    .font(.title2)

                Text(title)
                    .font(.headline)

                HStack(spacing: 8) {
                    Spacer()

                    Button(action: { error.copy() }) {
                        Image.copyIcon
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.borderless)
                    .help("复制内容")

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onDismiss()
                        }
                    }) {
                        Image.closeIcon
                            .foregroundStyle(.red.opacity(0.8))
                            .font(.title)
                    }
                    .buttonStyle(.borderless)
                    .help("关闭")
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(error.localizedDescription)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .applyToastStyling()
        .frame(
            minWidth: 300,
            idealWidth: 450,
            maxWidth: 600,
            minHeight: 200,
            idealHeight: 400,
            maxHeight: 500
        )
        .onAppear {
            onAppear?()
        }
    }
}

#if DEBUG
    #Preview {
        MagicRootView {
            MagicToastExampleView()
        }
        .frame(width: 400, height: 600)
    }

    #Preview("错误详情视图") {
        ToastErrorView(
            error: NSError(
                domain: "com.magickit.test",
                code: 1001,
                userInfo: [
                    NSLocalizedDescriptionKey: "网络连接失败，无法访问服务器端点",
                    NSLocalizedFailureReasonErrorKey: "服务器响应超时，可能是网络不稳定、服务器维护或防火墙阻拦",
                    NSLocalizedRecoverySuggestionErrorKey: "请检查网络连接状态，确认VPN设置，稍后重试。如果问题持续存在，请联系技术支持团队。",
                    NSHelpAnchorErrorKey: "访问帮助中心获取更多网络故障排除信息和常见问题解答",
                ]
            ),
            title: "网络请求失败",
            onDismiss: { print("关闭错误详情") },
            onAppear: { print("错误详情视图显示") }
        )
        .frame(width: 500, height: 600)
    }
#endif
