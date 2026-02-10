import SwiftUI

extension View {
    func asPosterTitle() -> some View {
        self.bold()
            .font(.system(size: 100, design: .rounded))
            .padding(.bottom, 40)
            .shadow(radius: 3)
    }

    func asPosterSubTitle(forMac: Bool = true) -> some View {
        let size: CGFloat = forMac ? 50 : 30

        return self.font(.system(size: size, design: .rounded))
            .foregroundStyle(.secondary)
            .shadow(radius: 2)
    }
}

// MARK: - Preview

#Preview("Poster Title") {
    VStack {
        Text("标题")
            .asPosterTitle()
        Text("副标题")
            .asPosterSubTitle()
    }
}
