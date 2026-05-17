import SwiftUI

/// Phase 2 写死的 demo 视图。
///
/// 用 `TimelineView(.animation)` 让 SwiftUI 持续重绘，配合渲染循环
/// 验证"子进程 SwiftUI runtime 持续输出 → 主进程持续接帧"的完整链路。
/// Phase 2.5 接入用户 dylib 之后，本视图会被替换为从 `previewEntrySymbol`
/// 加载的真实预览。
struct HotPreviewDemoView: View {
    var body: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            let s = sin(phase)
            let c = cos(phase)
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hue: (sin(phase * 0.3) + 1) / 2, saturation: 0.8, brightness: 0.6),
                        Color(hue: (cos(phase * 0.5) + 1) / 2, saturation: 0.8, brightness: 0.85)
                    ],
                    startPoint: UnitPoint(x: 0.5 + 0.5 * s, y: 0),
                    endPoint: UnitPoint(x: 0.5 + 0.5 * c, y: 1)
                )

                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 80, height: 80)
                    .offset(x: 60 * s, y: 30 * c)

                VStack(spacing: 6) {
                    Text("Lumi Inline Preview")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("Phase 2 demo · subprocess SwiftUI")
                        .font(.system(size: 11, design: .monospaced))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .shadow(radius: 1, y: 1)
            }
        }
    }
}
