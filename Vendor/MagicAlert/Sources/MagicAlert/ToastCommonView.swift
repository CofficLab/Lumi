import SwiftUI

/// 通用Toast视图组件
/// 用于显示标准的Toast内容，包括图标、标题、副标题和进度条
struct ToastCommonView: View {
    /// Toast模型数据
    let toast: ToastModel
    /// 进度条进度（0.0-1.0）
    let progress: Double
    /// 是否可见（用于加载动画）
    let isVisible: Bool
    /// 拖拽偏移
    @Binding var dragOffset: CGSize
    /// 关闭处理函数
    let onDismiss: (UUID) -> Void
    /// 手势关闭处理函数
    let handleToastDismiss: (DragGesture.Value?) -> Void
    /// 点击处理函数
    let handleToastTap: () -> Void
    /// 显示动画处理函数
    let handleToastAppearance: () -> Void

    var body: some View {
        VStack(spacing: 16) {

            // 图标
            Group {
                if case .loading = toast.type {
                    // 加载动画
                    Image(systemName: toast.type.systemImage)
                        .foregroundColor(toast.type.color)
                        .rotationEffect(.degrees(isVisible ? 360 : 0))
                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: isVisible)
                } else {
                    // 静态图标
                    Image(systemName: toast.type.systemImage)
                        .foregroundColor(toast.type.color)
                }
            }
            .font(.system(size: 64))
            .frame(width: 72, height: 72)

            // 内容
            VStack(spacing: 4) {
                Text(toast.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                if let subtitle = toast.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(width: 180, height: 180)
        .applyToastStyling()
        .gesture(
            toast.tapToDismiss ?
                DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    handleToastDismiss(value)
                }
                : nil
        )
        .onTapGesture(perform: handleToastTap)
        .onAppear(perform: handleToastAppearance)
        .overlay(alignment: .bottom) {
            // 进度条
            if toast.showProgress && toast.autoDismiss && toast.duration > 0 {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(toast.type.color)
                        .frame(width: geometry.size.width * progress, height: 2)
                        .animation(.linear(duration: toast.duration), value: progress)
                }
                .frame(height: 2)
            }
        }
    }
}

#if DEBUG
    #Preview("通用Toast视图") {
        let toast = ToastModel(
            type: .success,
            title: "操作成功",
            subtitle: "数据已保存",
            displayMode: .overlay,
            duration: 3.0,
            autoDismiss: true,
            tapToDismiss: true
        )

        return ToastCommonView(
            toast: toast,
            progress: 0.7,
            isVisible: true,
            dragOffset: .constant(.zero),
            onDismiss: { _ in print("关闭") },
            handleToastDismiss: { _ in print("手势关闭") },
            handleToastTap: { print("点击") },
            handleToastAppearance: { print("显示") }
        )
        .frame(width: 500)
        .frame(height: 500)
    }

    #Preview("带工具栏的Toast") {
        let toast = ToastModel(
            type: .info,
            title: "需要确认",
            subtitle: "此操作不可撤销",
            displayMode: .overlay,
            duration: 0,
            autoDismiss: false,
            tapToDismiss: false
        )

        return ToastCommonView(
            toast: toast,
            progress: 1.0,
            isVisible: true,
            dragOffset: .constant(.zero),
            onDismiss: { _ in print("关闭") },
            handleToastDismiss: { _ in print("手势关闭") },
            handleToastTap: { print("点击") },
            handleToastAppearance: { print("显示") }
        )
        .frame(width: 500)
        .frame(height: 500)
    }
#endif
