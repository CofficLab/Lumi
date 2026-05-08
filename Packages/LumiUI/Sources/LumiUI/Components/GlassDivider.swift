import SwiftUI

public struct GlassDivider: View {
    var thickness: CGFloat = 1
    var opacity: Double = 0.1

    public init(thickness: CGFloat = 1, opacity: Double = 0.1) {
        self.thickness = thickness
        self.opacity = opacity
    }

    public var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        SwiftUI.Color.clear,
                        SwiftUI.Color.white.opacity(opacity),
                        SwiftUI.Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: thickness)
    }
}
