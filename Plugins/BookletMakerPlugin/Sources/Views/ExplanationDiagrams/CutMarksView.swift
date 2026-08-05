import SwiftUI

// MARK: - Cut Marks View

/// 裁切标记视图
struct CutMarksView: View {
    let margin: CGFloat
    let gutter: CGFloat
    let showGutter: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let markLength: CGFloat = 6

            Path { path in
                // 四个角的裁切标记
                // 左上角
                path.move(to: CGPoint(x: margin - markLength, y: margin))
                path.addLine(to: CGPoint(x: margin, y: margin))
                path.move(to: CGPoint(x: margin, y: margin - markLength))
                path.addLine(to: CGPoint(x: margin, y: margin))

                // 右上角
                path.move(to: CGPoint(x: width - margin, y: margin))
                path.addLine(to: CGPoint(x: width - margin + markLength, y: margin))
                path.move(to: CGPoint(x: width - margin, y: margin - markLength))
                path.addLine(to: CGPoint(x: width - margin, y: margin))

                // 左下角
                path.move(to: CGPoint(x: margin - markLength, y: height - margin))
                path.addLine(to: CGPoint(x: margin, y: height - margin))
                path.move(to: CGPoint(x: margin, y: height - margin))
                path.addLine(to: CGPoint(x: margin, y: height - margin + markLength))

                // 右下角
                path.move(to: CGPoint(x: width - margin, y: height - margin))
                path.addLine(to: CGPoint(x: width - margin + markLength, y: height - margin))
                path.move(to: CGPoint(x: width - margin, y: height - margin))
                path.addLine(to: CGPoint(x: width - margin, y: height - margin + markLength))

                // 中间装订线处的裁切标记（仅 Booklet Fold 模式）
                if showGutter && gutter > 2 {
                    let centerX = width / 2
                    // 上中
                    path.move(to: CGPoint(x: centerX, y: margin - markLength))
                    path.addLine(to: CGPoint(x: centerX, y: margin))
                    // 下中
                    path.move(to: CGPoint(x: centerX, y: height - margin))
                    path.addLine(to: CGPoint(x: centerX, y: height - margin + markLength))
                }
            }
            .stroke(Color.secondary.opacity(0.5), lineWidth: 0.5)
        }
    }
}
