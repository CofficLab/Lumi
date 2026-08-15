import SwiftUI

/// 单色咖啡 Logo，用于菜单栏。
struct CofficMonochromeLogoView: View {
    let size: CGFloat

    var body: some View {
        let mainSize = size * 0.75

        ZStack {
            RoundedRectangle(cornerRadius: size * 0.08)
                .fill(.primary)
                .frame(width: mainSize * 0.7, height: mainSize * 0.6)

            RoundedRectangle(cornerRadius: size * 0.04)
                .fill(.primary.opacity(0.8))
                .frame(width: mainSize * 0.75, height: mainSize * 0.12)
                .offset(y: -mainSize * 0.28)

            Circle()
                .stroke(.primary, lineWidth: size * 0.04)
                .frame(width: mainSize * 0.25, height: mainSize * 0.25)
                .offset(x: mainSize * 0.38, y: -mainSize * 0.05)
        }
        .frame(width: size, height: size)
    }
}

#Preview("Monochrome Logo") {
    CofficMonochromeLogoView(size: 64)
}
