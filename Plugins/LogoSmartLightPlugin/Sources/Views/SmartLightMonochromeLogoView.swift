import SwiftUI

/// Monochrome smart light logo view
/// Used for statusBar scene
/// Menu bar icon rendered as monochrome template image (tinted by system), always monochrome, no active state.
struct SmartLightMonochromeLogoView: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "bolt.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.black)
            .frame(width: size, height: size)
    }
}

#Preview("Monochrome Logo") {
    SmartLightMonochromeLogoView(size: 64)
}