import SwiftUI

/// 单色智能灯 Logo，用于菜单栏。
struct SmartLightMonochromeLogoView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.primary)
                .frame(width: size * 0.8, height: size * 0.8)

            Image(systemName: "bolt.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.primary)
                .colorInvert()
                .frame(width: size * 0.5, height: size * 0.5)
        }
    }
}

#Preview("Monochrome Logo") {
    SmartLightMonochromeLogoView(size: 64)
}
