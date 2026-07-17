import SwiftUI

// MARK: - LoadingView

/// 应用启动时的 Loading 页面，优雅的 macOS 风格动画
struct LoadingView: View {
    var body: some View {
        ZStack {
            // 背景
            backgroundView

            // 内容
            VStack(spacing: 40) {
                Spacer()

                // 加载动画
                loadingIndicator

                // 加载文本
                loadingText

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Background

    private var backgroundView: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let maxRadius = max(geometry.size.width, geometry.size.height)

            RadialGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(0.08),
                    Color.accentColor.opacity(0.03),
                    Color(nsColor: .windowBackgroundColor).opacity(0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: maxRadius * 0.8
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Loading Indicator

    private var loadingIndicator: some View {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: 10, height: 10)
                    .scaleEffect(dotScale(for: index))
                    .opacity(dotOpacity(for: index))
            }
        }
        .frame(height: 40)
    }

    // MARK: - Loading Text

    private var loadingText: some View {
        VStack(spacing: 12) {
            Text("正在初始化")
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)

            Text("正在加载组件和插件...")
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Animation Helpers

    private func dotScale(for index: Int) -> CGFloat {
        let time = Date().timeIntervalSinceReferenceDate
        let phase = Double(index) * 0.4
        let sineValue = sin(time * 2.5 + phase)
        return CGFloat(sineValue * 0.35 + 0.65)
    }

    private func dotOpacity(for index: Int) -> CGFloat {
        let time = Date().timeIntervalSinceReferenceDate
        let phase = Double(index) * 0.4
        let sineValue = sin(time * 2.5 + phase)
        return CGFloat(sineValue * 0.4 + 0.6)
    }
}

// MARK: - Compact Loading View

/// 紧凑型 Loading 视图，用于嵌入到其他视图中
struct CompactLoadingView: View {
    var message: String = "加载中..."

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("LoadingView") {
        LoadingView()
    }

    #Preview("LoadingView - Light") {
        LoadingView()
        .preferredColorScheme(.light)
    }

    #Preview("LoadingView - Dark") {
        LoadingView()
        .preferredColorScheme(.dark)
    }

    #Preview("CompactLoadingView") {
        CompactLoadingView()
            .padding()
    }
#endif
