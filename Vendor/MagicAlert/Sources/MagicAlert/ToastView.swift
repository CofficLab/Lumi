import SwiftUI

/// Toast视图组件，负责显示不同类型的Toast通知
/// 支持标准Toast和错误详情两种显示模式，根据Toast类型自动选择合适的布局
struct ToastView: View {
    /// 要显示的Toast模型数据
    let toast: ToastModel
    /// 关闭Toast的回调函数
    let onDismiss: (UUID) -> Void

    /// 进度条动画进度（0.0-1.0）
    @State private var progress: Double = 1.0
    /// Toast是否可见，用于控制显示动画
    @State private var isVisible = false
    /// 拖拽偏移量，用于实现滑动关闭功能
    @State private var dragOffset = CGSize.zero

    var body: some View {
        // 根据类型显示不同的视图
        if case .errorDetail = toast.type {
            Group {
                if case let .errorDetail(error, title) = toast.type {
                    ToastErrorView(
                        error: error,
                        title: title,
                        onDismiss: { onDismiss(toast.id) },
                        onAppear: handleToastAppearance
                    )
                }
            }
        } else {
            ToastCommonView(
                toast: toast,
                progress: progress,
                isVisible: isVisible,
                dragOffset: $dragOffset,
                onDismiss: onDismiss,
                handleToastDismiss: handleToastDismiss,
                handleToastTap: handleToastTap,
                handleToastAppearance: handleToastAppearance
            )
        }
    }
}

// MARK: - Event Handler

extension ToastView {
    /// 处理Toast显示动画
    private func handleToastAppearance() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isVisible = true
        }

        // 进度条动画
        if toast.autoDismiss && toast.duration > 0 {
            withAnimation(.linear(duration: toast.duration)) {
                progress = 0.0
            }
        }
    }

    /// 处理Toast关闭事件
    /// - Parameter gestureValue: 拖拽手势的值，用于判断是否应该关闭
    private func handleToastDismiss(_ gestureValue: DragGesture.Value? = nil) {
        if let gestureValue = gestureValue {
            // 通过拖拽关闭
            if abs(gestureValue.translation.height) > 50 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onDismiss(toast.id)
                }
            } else {
                withAnimation(.spring()) {
                    dragOffset = .zero
                }
            }
        } else {
            // 通过点击关闭
            withAnimation(.easeInOut(duration: 0.3)) {
                onDismiss(toast.id)
            }
        }
    }

    /// 处理Toast点击事件
    private func handleToastTap() {
        if toast.tapToDismiss {
            toast.onTap?()
            withAnimation(.easeInOut(duration: 0.3)) {
                onDismiss(toast.id)
            }
        } else {
            toast.onTap?()
        }
    }
}

#if DEBUG
    #Preview {
        MagicToastExampleView()
            .withMagicToast()
            .frame(width: 400, height: 600)
    }
#endif
